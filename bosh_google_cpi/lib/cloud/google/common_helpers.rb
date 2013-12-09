module Bosh::Google

  module CommonHelpers

    %w(validate_options initialize_registry).each do |m|
      define_method m do 
        puts "TODO: Implement Helpers##{m} method."
      end
    end 


    def remote_google_connection
      retries = 0
      begin
        yield
      rescue Excon::Errors::RequestEntityTooLarge => e
        # If we find a rate limit error, parse message, wait, and retry
        overlimit = parse_google_response(e.response, "overLimit", "overLimitFault")
        unless overlimit.nil? || retries >= MAX_RETRIES
          task_checkpoint
          wait_time = overlimit["retryAfter"] || e.response.headers["Retry-After"] || DEFAULT_RETRY_TIMEOUT
          details = "#{overlimit["message"]} - #{overlimit["details"]}"
          @logger.debug("Google API Over Limit (#{details}), waiting #{wait_time} seconds before retrying") if @logger
          sleep(wait_time.to_i)
          retries += 1
          retry
        end
        cloud_error("Google API Request Entity Too Large error. Check task debug log for details.", e)
      rescue Excon::Errors::BadRequest => e
        badrequest = parse_google_response(e.response, "badRequest")
        details = badrequest.nil? ? "" : " (#{badrequest["message"]})"   
        cloud_error("Google API Bad Request#{details}. Check task debug log for details.", e)
      rescue Excon::Errors::InternalServerError => e
        unless retries >= MAX_RETRIES
          retries += 1
          @logger.debug("Google API Internal Server error, retrying (#{retries})") if @logger
          sleep(DEFAULT_RETRY_TIMEOUT)
          retry
        end
        cloud_error("Google API Internal Server error. Check task debug log for details.", e)
      end
    end

    alias_method :remote, :remote_google_connection

    def cloud_error(message, exception = nil)
      @logger.error(message) if @logger
      @logger.error(exception) if @logger && exception
      raise Bosh::Clouds::CloudError, message
    end

    ##
    # Unpacks a stemcell archive
    #
    # @param [String] tmp_dir Temporary directory
    # @param [String] image_path Local filesystem path to a stemcell image
    # @return [void]
    def unpack_image(tmp_dir, image_path)
      result = Bosh::Exec.sh("tar -C #{tmp_dir} -xzf #{image_path} 2>&1", :on_error => :return)
      if result.failed?
        @logger.error("Extracting stemcell root image failed in dir #{tmp_dir}, " +
                      "tar returned #{result.exit_status}, output: #{result.output}")
        cloud_error("Extracting stemcell root image failed. Check task debug log for details.")
      end
      root_image = File.join(tmp_dir, image_root_file)
      unless File.exists?(root_image)
        cloud_error("Root image is missing from stemcell archive.")
      end
    end    


  end

end