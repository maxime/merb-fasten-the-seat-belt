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
      self.property :size, Integer, :lazy => true
      self.property :content_type, String, :lazy => true
      self.property :created_at, DateTime, :lazy => true
      self.property :updated_at, DateTime, :lazy => true
    
      self.property :images_are_compressed, TrueClass, :lazy => true
    
      # Callbacks to manage the file
      before :save, :save_attributes
      after :save, :save_file
      after :destroy, :delete_directory
      
      # Options
      options[:path_prefix] = 'public' unless options[:path_prefix]
      options[:path_prefix] = "public/#{options[:path_prefix]}"
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
      all.each {|object| object.generate_thumbnails! }
      true
    end
  end
  
  module InstanceMethods
    
    # Get file path
    #
    def path(thumb=nil)
      return nil unless self.filename
      
      if thumb != nil
        basename = self.filename.gsub(/\.(.*)$/, '')
        extension = self.filename.gsub(/^(.*)\./, '')
        filename = basename + '_' + thumb.to_s + '.' + extension
      else
        filename = self.filename
      end

      complete_web_directory + "/" + filename
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

      Merb.logger.info "Saving file #{complete_file_path}..."
      
      create_directory

      FileUtils.mv @file[:tempfile].path, complete_file_path if File.exists?(@file[:tempfile].path)
      
      generate_thumbnails!
      
      @file = nil
      
      self.images_are_compressed ||= true 
    end
    
    def directory_name
      # you can thank Jamis Buck for this: http://www.37signals.com/svn/archives2/id_partitioning.php
      dir = ("%08d" % self.id).scan(/..../)
      "#{dir[0]}/#{dir[1]}"
    end
    
    def complete_web_directory
      dir = '/' + self.class.fasten_the_seat_belt_options[:path_prefix]+"/#{Merb.env.intern}/#{self.class.storage_name}/#{directory_name}"
      dir.gsub!(/^\/public/, '')
      dir
    end
    
    def complete_directory_name
      Merb.root + '/public' + complete_web_directory
    end
  
    def complete_file_path
      complete_directory_name + "/" + self.filename
    end

    def create_directory
      FileUtils.mkdir_p(complete_directory_name) unless FileTest.exists?(complete_directory_name)
    end

    def delete_directory 
      FileUtils.rm_rf(complete_directory_name) if FileTest.exists?(complete_directory_name)
    end

    def generate_thumbnails!
      Merb.logger.info "Generate thumbnails..."
      self.class.fasten_the_seat_belt_options[:thumbnails].each_pair do |key, value|
        resize_to = value[:size]
        quality = value[:quality].to_i
        
        image = MiniMagick::Image.from_file(complete_file_path)
        if value[:crop]
          # tw, th are target width and target height
          
          tw = resize_to.gsub(/([0-9]*)x([0-9]*)/, '\1').to_i
          th = resize_to.gsub(/([0-9]*)x([0-9]*)/, '\2').to_i
          
          # ow and oh are origin width and origin height
          ow = image[:width]
          oh = image[:height]
          
          # iw and ih and the dimensions of the cropped picture before resizing
          # there are 2 cases, iw = ow or ih = oh
          # using iw / ih = tw / th, we can determine the other values
          # we use the minimal values to determine the good case
          iw = [ow, ((oh.to_f*tw.to_f) / th.to_f)].min.to_i
          ih = [oh, ((ow.to_f*th.to_f) / tw.to_f)].min.to_i
          
          # we calculate how much image we must crop
          shave_width = ((ow.to_f - iw.to_f) / 2.0).to_i
          shave_height = ((oh.to_f - ih.to_f) / 2.0).to_i
          
  
          # specify the width of the region to be removed from both sides of the image and the height of the regions to be removed from top and bottom.
          image.shave "#{shave_width}x#{shave_height}"
          
          # resize of the pic
          image.resize resize_to
        else
          # no cropping
          image.resize resize_to
        end
        basename = self.filename.gsub(/\.(.*)$/, '')
        extension = self.filename.gsub(/^(.*)\./, '')

        thumb_filename = complete_directory_name + "/" +  basename + '_' + key.to_s + '.' + extension

        # Delete thumbnail if exists
        File.delete(thumb_filename) if File.exists?(thumb_filename)
        Merb.logger.info "Writing #{thumb_filename}..."
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
      system("jpegoptim \"#{filename}\" -m#{quality} --strip-all")
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
        
        basename = self.filename.gsub(/\.(.*)$/, '')
        extension = self.filename.gsub(/^(.*)\./, '')
        thumb_filename = complete_directory_name + "/" +  basename + '_' + key.to_s + '.' + extension
        
        if quality and quality < 100
          compress_jpeg(thumb_filename, quality)
        end
      end
      
      self.images_are_compressed = true
      self.save
    end
  end
end
