module Bosh::Google

  module Helpers

    include Bosh::Google::CommonHelpers

    %w(validate_options).each do |m|
      define_method m do 
        puts "TODO: Implement Helpers##{m} method."
      end
    end 

    def generate_unique_name_from_email
      Digest::MD5.hexdigest(client_email)
    end

    def generate_unique_name
      SecureRandom.hex
    end

    def generate_timestamp
      Time.now.strftime('-%Y%m%d-%3N')
    end

    def client_email
      self.options['google']['compute']['client_email']
    end

    def stemcell_directory_name
      @stemcell_directory_name ||= "bosh-stemcells-#{generate_unique_name_from_email}"
    end

    def generate_stemcell_image_name(options = {})
      image = options[:from] || 'stemcell'
      File.basename(image, '.*').tr('^A-Za-z0-9\-', '') + '-' + generate_timestamp
    end

    def generate_vm_name
      File.basename(image_path, '.*').tr('^A-Za-z0-9\-', '') + '-' + generate_timestamp
    end    

    def stemcell_directory
      # check if folder exists and has access
      # TODO: what to do if DeniedAccess is thrown
      @logger.info("Connecting to stemcell directory (#{stemcell_directory_name})...")
      direcrtory = remote { @storage.directories.get(stemcell_directory_name) }
      if direcrtory.nil?
        @logger.info("Creating directory (#{stemcell_directory_name})...")
        remote do 
          direcrtory = @storage.directories.create(key: stemcell_directory_name)
          direcrtory.add_acl('AllUsers', 'READ')
          # direcrtory.add_acl({entity: 'allAuthenticatedUsers', role: 'READER'})
        end
      end
      direcrtory
    end
    

    def authenticate_google_compute(options)

      api_version   = 'v1'
      base_url      = 'https://www.googleapis.com/compute/'
      api_scope_url = 'https://www.googleapis.com/auth/compute'
      
      google_client_email = options[:google_client_email]
      @api_url            = base_url + api_version + '/projects/'

      google_client_email = options[:google_client_email]

      key = Google::APIClient::KeyUtils.load_from_pkcs12(File.expand_path(options[:google_key_location]), 'notasecret')

      @google_client = ::Google::APIClient.new({
        :application_name => "bosh_google_cpi",
        :application_version => Bosh::Clouds::VERSION
      })

      @google_client.authorization = Signet::OAuth2::Client.new({
        :audience => 'https://accounts.google.com/o/oauth2/token',
        :auth_provider_x509_cert_url => "https://www.googleapis.com/oauth2/v1/certs",
        :client_x509_cert_url => "https://www.googleapis.com/robot/v1/metadata/x509/#{google_client_email}",
        :issuer => google_client_email,
        :scope => api_scope_url,
        :signing_key => key,
        :token_credential_uri => 'https://accounts.google.com/o/oauth2/token',
      })
      @google_client.authorization.fetch_access_token!
      @google_compute = @google_client.discovered_api('compute', api_version)
      
    end

  #   ##
  #   # Checks if options passed to CPI are valid and can actually
  #   # be used to create all required data structures etc.
  #   #
  #   # @return [void]
  #   # @raise [ArgumentError] if options are not valid
  #   def validate_options

  #     %w(compute storage).each do |key|
  #       raise "#{compute} should be present and should be true" if @options[key]
  #     end

  #     unless @options["google"].is_a?(Hash) &&
  #            @options["google"]["auth_url"] &&
  #            @options["google"]["username"] &&
  #            @options["google"]["api_key"] &&
  #            @options["google"]["tenant"]
  #       raise ArgumentError, "Invalid OpenStack configuration parameters"
  #     end

  #     unless @options.has_key?("registry") &&
  #         @options["registry"].is_a?(Hash) &&
  #         @options["registry"]["endpoint"] &&
  #         @options["registry"]["user"] &&
  #         @options["registry"]["password"]
  #       raise ArgumentError, "Invalid registry configuration parameters"
  #     end
  #   end


    ##
    # Inits registry
    #
    def initialize_registry
      registry_properties = @options.fetch('registry')
      registry_endpoint   = registry_properties.fetch('endpoint')
      registry_user       = registry_properties.fetch('user')
      registry_password   = registry_properties.fetch('password')

      puts "initialize_registry with #{[registry_endpoint, registry_user, registry_password].inspect}."
      @registry = Bosh::Registry::Client.new(registry_endpoint, registry_user, registry_password)
    end

    # ??? do we need root_device_name 
    def agent_registry_settings(agent_id, vm_name, environment, system_disk_name, ephemeral_disk_name = nil)
      settings = {
        "vm" => { "name" => vm_name },
        "agent_id" => agent_id, 
        "env" => environment, 
        "disks" => {
          "system"    => system_disk_name,
          "ephemeral" => ephemeral_disk_name,
          "persistent" => {}
        }
      }
      settings.merge(agent_properties)
    end

    def update_agent_settings(options = {})
      instance_id = options[:instance]
      settings_path = options[:settings] || []

      unless block_given?
        raise ArgumentError, "block is not provided"
      end

      settings = registry.read_settings(instance_id)
      
      # create necessary deep hash structure inside settings 
      # for instance for settings = {} and settings_path = %w(a1 a2)
      # settings should be equeal settings = {'a1' => {'a2' => {}}}
      hash ||= settings[settings_path.shift] ||= {}
      settings_path.each { |key| hash = (hash[key] ||= {}); }

      yield settings if block_given?

      p [:update_agent_settings, settings]
      registry.update_settings(instance_id, settings)


    end    

    def agent_properties
      @agent_properties ||= options.fetch('agent', {})
    end

    def find_by_identity(collection, identity)
      collection.find { |server| server.identity == identity }
    end

    def find_server_by_identity(id)
      find_by_identity(@compute.servers, id)
    end

  end

end