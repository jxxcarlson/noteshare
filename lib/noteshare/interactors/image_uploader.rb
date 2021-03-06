require 'lotus/interactor'
require_relative '../../../lib/modules/analytics'
require_relative '../../../lib/aws'
# require_relative '../../../lib/noteshare/entities/image'
require_relative '../entities/image'

module Noteshare
  module Interactor
    module Image

      class ImageUploader

        include Lotus::Interactor
        include ::Noteshare::Util
        include ::Noteshare::Core::Image

        expose :url, :image, :message, :originating_document_id

        def initialize(params, user)
          @user = user
          @title =  params['title']
          @tags =  params['tags']
          @datafile_packet = params['datafile'] || {}
          @filename = @datafile_packet['filename']
          @incoming_url = params['url']
          @option = params['option']
          @originating_document_id = params['originating_document_id']
        end

        def set_mode
          if @incoming_url && @incoming_url =~ /http/
            @mode = :from_url
          else
            @mode = :from_local_file
          end
        end

        def set_tempfile
          if @mode == :from_local_file
            @tempfile = @datafile_packet['tempfile'].inspect.match(/Tempfile:(.*)>/)[1]
          else
            @filename = @title.normalize
            file_suffix = @incoming_url.split('.').last
            @tempfile = "outgoing/#{@filename}.#{file_suffix}"
          end
        end

        def set_filename
          _identifier = Identifier.new('image').string
          if @mode == :from_url
            @filename =  "#{_identifier}_#{@title.normalize}"
          else
            @filename =  "#{_identifier}_#{@filename}"
          end

        end

        def configure
          set_mode
          set_tempfile
          set_filename
        end

        def bail_out
          @message = "Image upload failed"
          return
        end

        def ensure_directory
          exec 'mkdir -p outgoing/images' unless Dir.exists? 'outgoing/images'
          if Dir.exists? 'outgoing/images'
            puts "outgoing/images EXISTS".red
          else
            puts "outgoing/images DOES NOT EXIST".red
          end
        end

        def upload
          if @mode == :from_url
            # binding.pry
            Util.save_url_to_file(@incoming_url, @tempfile)
            @url = Noteshare::AWS.upload(@filename, @tempfile, 'noteshare_images' )
          else
            @url = Noteshare::AWS.upload(@filename, @tempfile, 'noteshare_images' )
          end
        end

        def call
          configure
          upload
          bail_out unless @url
          raw_image = Noteshare::Core::Image::Image.new(title: @title, file_name: @filename, url: @url, tags: @tags, dict: {})
          @image = ImageRepository.create raw_image
          @user.dict2['current_image_id'] = @image.id
          Analytics.record_image_upload(@user, @image)
          UserRepository.update @user
          @message = "Image upload successful (id: #{@image.id})"
        end

      end

    end
  end
end
