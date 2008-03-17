require 'mini_magick'

module FastenTheSeatBelt
  def self.included(base)
    Merb.logger.info "FastenTheSeatBelt just got included into #{base.inspect}"
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
      #class << self
        Picture.property :filename,   :string
        Picture.property :size, :integer
        Picture.property :content_type, :string
        Picture.property :created_at, :datetime
        Picture.property :updated_at, :datetime
      #end
    
      # Callbacks to manage the file
      before_save :save_attributes
      after_save :save_file
      after_destroy :delete_file_and_directory
      
      # Options
      options[:path_prefix] = 'public' unless options[:path_prefix]
      options[:thumbnails] ||= {}

      @@fasten_the_seat_belt = options
    end
    
    def table_name
      Picture.table.to_s
    end
    
    def fasten_the_seat_belt_options
      @@fasten_the_seat_belt
    end
  end
  
  module InstanceMethods
    
    # Get file path
    #
    def path(thumb=nil)
      return '' unless self.filename
      dir = ("%08d" % self.id).scan(/..../)
      basename = self.filename.gsub(/\.(.*)$/, '')
      extension = self.filename.gsub(/^(.*)\./, '')

      if thumb != nil
        filename = basename + '_' + thumb.to_s + '.' + extension
      else
        filename = self.filename
      end

      "/files/#{self.class.table_name}/"+dir[0]+"/"+dir[1] + "/" + filename
    end  
            
    def save_attributes
      Merb.logger.info "saving attributes..."
      return false unless @file
      Merb.logger.info "saving them now"
      # Setup attributes
      [:content_type, :size, :filename].each do |attribute|
        self.send("#{attribute}=", @file[attribute])
      end
    end

    def save_file
      Merb.logger.info "Saving file #{self.filename}..."
      return false unless self.filename and @file

      # Create directories
      create_root_directory

      # you can thank Jamis Buck for this: http://www.37signals.com/svn/archives2/id_partitioning.php
      dir = ("%08d" % self.id).scan(/..../)

      FileUtils.mkdir(self.class.fasten_the_seat_belt_options[:path_prefix]+"/#{self.class.table_name}/"+dir[0]) unless FileTest.exists?(self.class.fasten_the_seat_belt_options[:path_prefix]+"/#{self.class.table_name}/"+dir[0])
      FileUtils.mkdir(self.class.fasten_the_seat_belt_options[:path_prefix]+"/#{self.class.table_name}/"+dir[0]+"/"+dir[1]) unless FileTest.exists?(self.class.fasten_the_seat_belt_options[:path_prefix]+"/#{self.class.table_name}/"+dir[0]+"/"+dir[1])

      destination = self.class.fasten_the_seat_belt_options[:path_prefix]+"/#{self.class.table_name}/"+dir[0]+"/"+dir[1] + "/" + self.filename
      FileUtils.mv @file[:tempfile].path, destination

      generate_thumbnails
    end

    def create_root_directory
      root_directory = self.class.fasten_the_seat_belt_options[:path_prefix] + "/#{self.class.table_name}"
      FileUtils.mkdir(root_directory) unless FileTest.exists?(root_directory)
    end

    def delete_file_and_directory    
      # delete directory
      dir = ("%08d" % self.id).scan(/..../)
      FileUtils.rm_rf(self.class.fasten_the_seat_belt_options[:path_prefix]+'/#{self.class.table_name}/'+dir[0]+"/"+dir[1]) if FileTest.exists?(self.class.fasten_the_seat_belt_options[:path_prefix]+'/#{self.class.table_name}/'+dir[0]+"/"+dir[1])
      #FileUtils.remove(fasten_the_seat_belt[:path_prefix]+'/pictures/'+dir[0]) if FileTest.exists?(fasten_the_seat_belt[:path_prefix]+'/pictures/'+dir[0]) 
    end

    def generate_thumbnails
      dir = ("%08d" % self.id).scan(/..../)
      Merb.logger.info "Generate thumbnails... id: #{self.id} path_prefix:#{self.class.fasten_the_seat_belt_options[:path_prefix]} dir0:#{dir[0]} dir1:#{dir[1]} filename:#{self.filename}"
      self.class.fasten_the_seat_belt_options[:thumbnails].each_pair do |key, value|
        image = MiniMagick::Image.from_file(File.join(Merb.root, (self.class.fasten_the_seat_belt_options[:path_prefix]+ "/#{self.class.table_name}/" + dir[0]+"/"+dir[1] + "/" + self.filename)))
        image.resize value

        basename = self.filename.gsub(/\.(.*)$/, '')
        extension = self.filename.gsub(/^(.*)\./, '')

        thumb_filename = self.class.fasten_the_seat_belt_options[:path_prefix]+ "/#{self.class.table_name}/" + dir[0]+"/"+dir[1] + "/" +  basename + '_' + key.to_s + '.' + extension

        image.write thumb_filename
      end
    end
  end
end