module Bosh::Registry

  class InstanceManager

    class Google < InstanceManager

      def initialize(cloud_config)
        validate_options(cloud_config)

        @logger = Bosh::Registry.logger

        @google_properties = cloud_config['google']

        @google_options = {
          :provider => 'Google',
          :google_client_email => @google_properties['client_email'],
          :google_key_location => @google_properties['client_key_path'],
          :google_project => @google_properties['project'],
          :connection_options => @google_properties['connection_options']
        }
      end

      def google
        @google ||= Fog::Compute.new(@google_options)
      end

      def validate_options(cloud_config)
        unless cloud_config.has_key?('google') &&
            cloud_config['google'].is_a?(Hash) &&
            cloud_config['google']['compute'].is_a?(Hash) &&
            cloud_config['google']['compute']['client_email'] &&
            cloud_config['google']['compute']['client_key_path'] &&
            cloud_config['google']['compute']['project']
          raise ConfigError, 'Invalid Google configuration parameters'
        end
      end

      # Get the list of IPs belonging to this instance
      def instance_ips(instance_id)
        # If we get an Unauthorized error, it could mean that the OpenStack auth token has expired, so we are
        # going renew the fog connection one time to make sure that we get a new non-expired token.
        retried = false
        begin
          instance  = google.servers.find { |s| s.name == instance_id }
        rescue Excon::Errors::Unauthorized => e
          unless retried
            retried = true
            @openstack = nil
            retry
          end
          raise ConnectionError, "Unable to connect to Google API: #{e.message}"
        end
        raise InstanceNotFound, "Instance `#{instance_id}' not found" unless instance
        return [instance.public_ip_address]
      end

    end

  end

end
