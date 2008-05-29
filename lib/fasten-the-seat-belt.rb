require 'mini_magick'

module FastenTheSeatBelt
  def self.included(base)
    base.send(:extend, ClassMethods)
    base.send(:include, InstanceMethods)
    base.send(:include, MiniMagick)
    base.class_eval do
      attr_accessor :file
    end
  end
  
  module ClassMethods
    def fasten_the_seat_belt(options={})
      # Properties
      self.property :filename, String
      self.property :size, Integer
      self.property :content_type, String
      self.property :created_at, DateTime
      self.property :updated_at, DateTime
    
      self.property :images_are_compressed, TrueClass
    
      # Callbacks to manage the file
      before :save, :save_attributes
      after :save, :save_file
      after :destroy, :delete_file_and_directory
      
      # Options
      options[:path_prefix] = 'public' unless options[:path_prefix]
      options[:thumbnails] ||= {}
      
      if options[:content_types]
        #self.validates_true_for :file, :logic => lambda { verify_content_type }, :message => "File type is incorrect"
      end
      
      options[:content_types] = [options[:content_types]] if options[:content_types] and options[:content_types].class != Array
      
      @@fasten_the_seat_belt = options
    end
    
    def fasten_the_seat_belt_options
      @@fasten_the_seat_belt
    end
    
    def recreate_thumnails!
      each {|object| object.generate_thumbnails! }
      true
    end
  end
  
  module InstanceMethods
    
    # Get file path
    #
    def path(thumb=nil)
      return nil unless self.filename
      dir = ("%08d" % self.id).scan(/..../)
      basename = self.filename.gsub(/\.(.*)$/, '')
      extension = self.filename.gsub(/^(.*)\./, '')

      if thumb != nil
        filename = basename + '_' + thumb.to_s + '.' + extension
      else
        filename = self.filename
      end

      "/files/#{self.class.storage_name}/"+dir[0]+"/"+dir[1] + "/" + filename
    end  
            
    def save_attributes
      return unless @file
      
      # Setup attributes
      [:content_type, :size, :filename].each do |attribute|
        self.send("#{attribute}=", @file[attribute])
      end
    end

    def save_file
      return unless self.filename and @file

      Merb.logger.info "Saving file #{self.filename}..."
      Merb.logger.info "self.id #{self.id}"
      Merb.logger.info "self.new_record? #{self.new_record?}"
      # Create directories
      create_root_directory

      # you can thank Jamis Buck for this: http://www.37signals.com/svn/archives2/id_partitioning.php
      dir = ("%08d" % self.id).scan(/..../)

      FileUtils.mkdir(self.class.fasten_the_seat_belt_options[:path_prefix]+"/#{self.class.storage_name}/"+dir[0]) unless FileTest.exists?(self.class.fasten_the_seat_belt_options[:path_prefix]+"/#{self.class.storage_name}/"+dir[0])
      FileUtils.mkdir(self.class.fasten_the_seat_belt_options[:path_prefix]+"/#{self.class.storage_name}/"+dir[0]+"/"+dir[1]) unless FileTest.exists?(self.class.fasten_the_seat_belt_options[:path_prefix]+"/#{self.class.storage_name}/"+dir[0]+"/"+dir[1])

      destination = self.class.fasten_the_seat_belt_options[:path_prefix]+"/#{self.class.storage_name}/"+dir[0]+"/"+dir[1] + "/" + self.filename
      if File.exists?(@file[:tempfile].path)
        FileUtils.mv @file[:tempfile].path, destination
      end
      
      generate_thumbnails!
      
      @file = nil
      
      self.images_are_compressed ||= true 
    end

    def create_root_directory
      root_directory = Merb.root + '/' + self.class.fasten_the_seat_belt_options[:path_prefix] + "/#{self.class.storage_name}"
      FileUtils.mkdir(root_directory) unless FileTest.exists?(root_directory)
    end

    def delete_file_and_directory    
      # delete directory
      dir = ("%08d" % self.id).scan(/..../)
      FileUtils.rm_rf(self.class.fasten_the_seat_belt_options[:path_prefix]+'/#{self.class.storage_name}/'+dir[0]+"/"+dir[1]) if FileTest.exists?(self.class.fasten_the_seat_belt_options[:path_prefix]+'/#{self.class.storage_name}/'+dir[0]+"/"+dir[1])
      #FileUtils.remove(fasten_the_seat_belt[:path_prefix]+'/pictures/'+dir[0]) if FileTest.exists?(fasten_the_seat_belt[:path_prefix]+'/pictures/'+dir[0]) 
    end

    def generate_thumbnails!
      dir = ("%08d" % self.id).scan(/..../)
      Merb.logger.info "Generate thumbnails... id: #{self.id} path_prefix:#{self.class.fasten_the_seat_belt_options[:path_prefix]} dir0:#{dir[0]} dir1:#{dir[1]} filename:#{self.filename}"
      self.class.fasten_the_seat_belt_options[:thumbnails].each_pair do |key, value|
        resize_to = value[:size]
        quality = value[:quality].to_i
        
        image = MiniMagick::Image.from_file(File.join(Merb.root, (self.class.fasten_the_seat_belt_options[:path_prefix]+ "/#{self.class.storage_name}/" + dir[0]+"/"+dir[1] + "/" + self.filename)))
        image.resize resize_to

        basename = self.filename.gsub(/\.(.*)$/, '')
        extension = self.filename.gsub(/^(.*)\./, '')

        thumb_filename = self.class.fasten_the_seat_belt_options[:path_prefix]+ "/#{self.class.storage_name}/" + dir[0]+"/"+dir[1] + "/" +  basename + '_' + key.to_s + '.' + extension

        # Delete thumbnail if exists
        File.delete(thumb_filename) if File.exists?(thumb_filename)
        
        image.write thumb_filename
        
        next if ((self.images_are_compressed == false) || (Merb.env=="test"))
        
        if quality and !["image/jpeg", "image/jpg"].include?(self.content_type) 
          puts "FastenTheSeatBelt says: Quality setting not supported for #{self.content_type} files"
          next
        end
        
        if quality and quality < 100
          compress_jpeg(thumb_filename, quality)
        end
      end
    end
    
    def verify_content_type
      true || self.class.fasten_the_seat_belt_options[:content_types].include?(self.content_type)
    end
    
    def dont_compress_now!
      @dont_compress_now = true
    end
    
    def compress_jpeg(filename, quality)
      # puts "FastenTheSeatBelt says: Compressing #{filename} to quality #{quality}"
      system("jpegoptim #{filename} -m#{quality} --strip-all")
    end
    
    def compress_now!
      return false if self.images_are_compressed
      
      self.class.fasten_the_seat_belt_options[:thumbnails].each_pair do |key, value|
        resize_to = value[:size]
        quality = value[:quality].to_i
      
        if quality and !["image/jpeg", "image/jpg"].include?(self.content_type) 
          puts "FastenTheSeatBelt says: Quality setting not supported for #{self.content_type} files"
          next
        end
        
        dir = ("%08d" % self.id).scan(/..../)
        basename = self.filename.gsub(/\.(.*)$/, '')
        extension = self.filename.gsub(/^(.*)\./, '')
        thumb_filename = self.class.fasten_the_seat_belt_options[:path_prefix]+ "/#{self.class.storage_name}/" + dir[0]+"/"+dir[1] + "/" +  basename + '_' + key.to_s + '.' + extension
        
        if quality and quality < 100
          compress_jpeg(thumb_filename, quality)
        end
      end
      
      self.images_are_compressed = true
      self.save
    end
  end
end
