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

    DEFAULT_STATE_TIMEOUT = 60

    def wait_resource(resource, target_state, state_method = :status, allow_notfound = false)
      started_at = Time.now
      desc = resource.class.name.split("::").last.to_s + " `" + resource.id.to_s + "'"
      target_state = Array(target_state)
      state_timeout = @state_timeout || DEFAULT_STATE_TIMEOUT

      @logger.info("Wait resource..")
      @logger.info("Description #{desc}..")
      @logger.info "Resource -> " + resource.inspect
      @logger.info("Started at #{started_at}.")

      loop do
        task_checkpoint

        duration = Time.now - started_at
        @logger.info("Duration #{duration}..")

        if duration > state_timeout
          cloud_error("Timed out waiting for #{desc} to be #{target_state.join(", ")}")
        end

        if @logger
          @logger.debug("Waiting for #{desc} to be #{target_state.join(", ")} (#{duration}s)")
        end

        # If resource reload is nil, perhaps it's because resource went away
        # (ie: a destroy operation). Don't raise an exception if this is
        # expected (allow_notfound).
        
        if remote { resource.reload.nil? }
          @logger.info("Resource reload is nil.")
          break if allow_notfound
          cloud_error("#{desc}: Resource not found")
        else
          @logger.info resource.inspect
          state =  remote { resource.send(state_method).downcase.to_sym }
        end

        # This is not a very strong convention, but some resources
        # have 'error', 'failed' and 'killed' states, we probably don't want to keep
        # waiting if we're in these states. Alternatively we could introduce a
        # set of 'loop breaker' states but that doesn't seem very helpful
        # at the moment
        if state == :failed
          cloud_error("#{desc} state is #{state}, expected #{target_state.join(", ")}")
        end

        break if target_state.include?(state)

        sleep(1)
      end

      if @logger
        total = Time.now - started_at
        @logger.info("#{desc} is now #{target_state.join(", ")}, took #{total}s")
      end
    end  


    def task_checkpoint
      @logger.info("task_checkpoint..")
      Bosh::Clouds::Config.task_checkpoint
    end


  end

end