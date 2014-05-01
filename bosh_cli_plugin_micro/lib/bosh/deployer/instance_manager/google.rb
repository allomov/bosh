require 'base64'

module Bosh::Deployer
  class InstanceManager
    class Google < InstanceManager

      # it goes to the VM after apply spec
      def update_spec(spec)
        properties = spec.properties

        properties['google'] =
          Config.spec_properties['google'] ||
          Config.cloud_options['properties']['google'].dup

        properties['google']['registry'] = Config.cloud_options['properties']['registry']
        properties['google']['stemcell'] = Config.cloud_options['properties']['stemcell']

        spec.delete('networks')
      end

      # rubocop:disable MethodLength
      def configure
        properties = Config.cloud_options['properties']


        @ssh_user = properties['google']['ssh_user']
        @ssh_port = properties['google']['ssh_port'] || 22
        @ssh_wait = properties['google']['ssh_wait'] || 60
        
        # key = properties['google']['private_key']
        # err 'Missing properties.google.private_key' unless key
        # @ssh_key = File.expand_path(key)    # here we have binary data and we convert it to b64 to send it as JSON
        # unless File.exists?(@ssh_key) 
        #   err "properties.google.private_key '#{key}' does not exist"
        # end
        
        compute_options = properties['google']['compute']
        key_path_options_with_hints = {
          'client_key_path'  => 'Client Private Key file. Read more here: ' + 
                                'https://developers.google.com/drive/web/service-accounts#' +
                                'console_name_project_service_accounts',
          'public_key_path'  => 'Public key that will be passed to instances created in GCE.', 
          'private_key_path' => 'Private SSH key that will be used to access instances created in GCE.'
        }

        key_path_options_with_hints.each do |key_path_option_name, hint|
          key_path = compute_options[key_path_option_name]
          if File.exists?(key_path)
            key_passed_to_templates = key_path_option_name.gsub(/_path$/, '')
            properties['google']['compute'].merge!(key_passed_to_templates => Base64.encode64(File.read(key_path)))
          else
            err("cloud.properties.google.compute.#{option_name} '#{key_path}' does not exist. " + hint)
          end
        end
        p [:google, :configure, properties['google']['compute']]
        

        uri = URI.parse(properties['registry']['endpoint'])
        user, password = uri.userinfo.split(':', 2)
        @registry_port = uri.port

        @registry_db = Tempfile.new('bosh_registry_db')
        @registry_connection_settings = {
          'adapter' => 'sqlite',
          'database' => @registry_db.path
        }

        registry_config = {
          'logfile' => './bosh-registry.log',
          'http' => {
            'port' => uri.port,
            'user' => user,
            'password' => password
          },
          'db' => @registry_connection_settings,
          'cloud' => {
            'plugin' => 'google',
            'google' => properties['google']
          }
        }

        @registry_config = Tempfile.new('bosh_registry_yml')
        @registry_config.write(Psych.dump(registry_config))
        @registry_config.close
      end
      # rubocop:enable MethodLength

      # rubocop:disable MethodLength
      def start
        configure

        p [:registry, :start, :@registry_config, @registry_config]

        p [:registry, :start, :@registry_connection_settings, @registry_connection_settings]

        Sequel.connect(@registry_connection_settings) do |db|
          migrate(db)
          
          p [:registry, "@deployments['registry_instances']", @deployments['registry_instances']]

          instances = @deployments['registry_instances']

          p [:registry, "db[:registry_instances]", db[:registry_instances]]

          p [:registry, "instances", instances]

          db[:registry_instances].insert_multiple(instances) if instances
        end

        p [:registry, "has_bosh_registry?", has_bosh_registry?]

        unless has_bosh_registry?
          err 'bosh-registry command not found - ' +
            "run 'gem install bosh-registry'"
        end

        cmd = "bosh-registry -c #{@registry_config.path}"



        @registry_pid = spawn(cmd)

        p [:registry, :@registry_pid, @registry_pid]

        5.times do |i|
          sleep 0.5
          if Process.waitpid(@registry_pid, Process::WNOHANG)
            err "`#{cmd}` failed, exit status=#{$?.exitstatus}"
            p "AAAAAAAAAAAAAAAAaAAAAaaAA"
          end
          p [:registry, i, "Process.waitpid(@registry_pid, Process::WNOHANG)"]
        end


        timeout_time = Time.now.to_f + (60 * 5)
        http_client = HTTPClient.new

        p [:registry, :timeout_time, timeout_time]

        begin
          http_client.head("http://127.0.0.1:#{@registry_port}")
          sleep 0.5
        rescue URI::Error, SocketError, Errno::ECONNREFUSED, HTTPClient::ReceiveTimeoutError => e
          if timeout_time - Time.now.to_f > 0
            retry
          else
            err "Cannot access bosh-registry: #{e.message}"
            p "Cannot access bosh-registry: #{e.message}"
          end
        end

        logger.info("bosh-registry is ready on port #{@registry_port}")
        
        p [:registry, "bosh-registry is ready on port #{@registry_port}"]

      ensure
        @registry_config.unlink if @registry_config
        p [:registry, "@registry_config unlinked", @registry_config]
      end
      # rubocop:enable MethodLength

      def stop
        if @registry_pid && process_exists?(@registry_pid)
          Process.kill('INT', @registry_pid)
          Process.waitpid(@registry_pid)
        end

        return unless @registry_connection_settings

        Sequel.connect(@registry_connection_settings) do |db|
          @deployments['registry_instances'] = db[:registry_instances].map { |row| row }
        end

        save_state
        @registry_db.unlink if @registry_db
      end

      def discover_bosh_ip
        if exists? # state.vm_cid not nil ??
          logger.info("discovered bosh: state=#{state.inspect}")
          external_ip = cloud.compute.servers.get(state.vm_cid).public_ip_address
          puts external_ip.to_s
          
          ip = external_ip || service_ip

          if ip != Config.bosh_ip
            Config.bosh_ip = ip
            logger.info("discovered bosh ip=#{Config.bosh_ip}")
          end
        end

        super
      end

      def service_ip
        cloud.compute.servers.get(state.vm_cid).private_ip_address
      end

      # @return [Integer] size in MiB
      def disk_size(cid)
        # Google stores disk size in GiB but we work with MiB
        cloud.compute.disks.get(cid).size_gb * 1024
      end

      def persistent_disk_changed?
        # since OpenStack stores disk size in GiB and we use MiB there
        # is a risk of conversion errors which lead to an unnecessary
        # disk migration, so we need to do a double conversion
        # here to avoid that
        requested = (Config.resources['persistent_disk'] / 1024.0).ceil * 1024
        requested != disk_size(state.disk_cid)
      end

      private

      def has_bosh_registry?(path = ENV['PATH'])
        path.split(File::PATH_SEPARATOR).each do |dir|
          return true if File.exist?(File.join(dir, 'bosh-registry'))
        end
        false
      end

      def migrate(db)
        p [:migrate]
        db.create_table :registry_instances do
          primary_key :id
          column :instance_id, :text, unique: true, null: false
          column :settings, :text, null: false
        end
      end
    end
  end
end
