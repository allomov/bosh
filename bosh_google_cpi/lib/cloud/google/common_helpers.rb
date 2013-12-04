module Bosh::Google

  module CommonHelpers

    %w(validate_options initialize_registry).each do |m|
      define_method m do 
        puts "TODO: Implement Helpers##{m} method."
      end
    end 


    def remote_operation
      retries = 0
      begin
        yield
      rescue Excon::Errors::RequestEntityTooLarge => e
        # If we find a rate limit error, parse message, wait, and retry
        overlimit = parse_openstack_response(e.response, "overLimit", "overLimitFault")
        unless overlimit.nil? || retries >= MAX_RETRIES
          task_checkpoint
          wait_time = overlimit["retryAfter"] || e.response.headers["Retry-After"] || DEFAULT_RETRY_TIMEOUT
          details = "#{overlimit["message"]} - #{overlimit["details"]}"
          @logger.debug("OpenStack API Over Limit (#{details}), waiting #{wait_time} seconds before retrying") if @logger
          sleep(wait_time.to_i)
          retries += 1
          retry
        end
        cloud_error("OpenStack API Request Entity Too Large error. Check task debug log for details.", e)
      rescue Excon::Errors::BadRequest => e
        badrequest = parse_openstack_response(e.response, "badRequest")
        details = badrequest.nil? ? "" : " (#{badrequest["message"]})"   
        cloud_error("OpenStack API Bad Request#{details}. Check task debug log for details.", e)
      rescue Excon::Errors::InternalServerError => e
        unless retries >= MAX_RETRIES
          retries += 1
          @logger.debug("OpenStack API Internal Server error, retrying (#{retries})") if @logger
          sleep(DEFAULT_RETRY_TIMEOUT)
          retry
        end
        cloud_error("OpenStack API Internal Server error. Check task debug log for details.", e)
      end
    end

  end

end