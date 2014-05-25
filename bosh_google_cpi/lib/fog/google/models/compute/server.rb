require 'fog/compute/models/server'
require 'net/ssh/proxy/command'

module Fog
  module Compute
    class Google

      class Server < Fog::Compute::Server

        identity :name

        attribute :network_interfaces, :aliases => 'networkInterfaces'
        attribute :state, :aliases => 'status'
        attribute :zone_name, :aliases => 'zone'
        attribute :machine_type, :aliases => 'machineType'
        attribute :disks, :aliases => 'disks'
        attribute :metadata
        attribute :tags, :squash => 'items'
        attribute :self_link, :aliases => 'selfLink'

        attr_accessor :metadata_fingerprint

        alias_method "metadata setter", :metadata=
        
        def metadata=(metadata)
          raise "Metadata should be a Hash." unless metadata.is_a?(Hash)

          p [:metadata, metadata]

          if @metadata_fingerprint = metadata['fingerprint']
            metadata = metadata['items'].inject({}) { |h, v| h[v['key']] = v['value']; h }
          elsif metadata.values.any? { |v| v.is_a?(Hash) }
            raise "Metadata #{metadata.inspect} has hash values that are not accepted with Google Engine."
          end

          self.send("metadata setter", metadata)
        end

        def image_name=(args)
          Fog::Logger.deprecation("image_name= is no longer used [light_black](#{caller.first})[/]")
        end

        def image_name
          boot_disk = disks.first
          unless boot_disk.is_a?(Disk)
            source = boot_disk['source']
            match = source.match(%r{/zones/(.*)/disks/(.*)$})
            boot_disk = service.disks.get match[2], match[1]
          end
          boot_disk.source_image.nil? ? nil : boot_disk.source_image
        end

        def kernel=(args)
          Fog::Logger.deprecation("kernel= is no longer used [light_black](#{caller.first})[/]")
        end
        def kernel
          Fog::Logger.deprecation("kernel is no longer used [light_black](#{caller.first})[/]")
          nil
        end

        def flavor_id
          machine_type
        end

        def flavor_id=(flavor_id)
          machine_type = flavor_id
        end

        def destroy
          requires :name, :zone_name
          response = service.delete_server(name, zone_name)
          operation = service.operations.new(response.body)
          operation
        end
        alias_method :delete, :destroy

        # not used since v1
        def image
          Fog::Logger.deprecation("Server.image is deprecated, get source_image from boot disk")
          service.get_image(self.image_name.split('/')[-1])
        end

        def public_ip_address
          ip = nil
          if self.network_interfaces.respond_to? :each
            self.network_interfaces.each do |netif|
              if netif["accessConfigs"].respond_to? :each
                netif["accessConfigs"].each do |access_config|
                  if access_config["name"] == "External NAT"
                    ip = access_config['natIP']
                  end
                end
              end
            end
          end

          ip
        end

        def private_ip_address
          ip = nil
          if self.network_interfaces.respond_to? :first
            ip = self.network_interfaces.first['networkIP']
          end
          ip
        end

        def ready?
          requires :state
          self.state == RUNNING
        end

        def add_ssh_key username, key
          if self.metadata.nil?
            self.metadata = Hash.new("")
          end

          # You can have multiple SSH keys, seperated by newlines.
          # https://developers.google.com/compute/docs/console?hl=en#sshkeys
          if !self.metadata["sshKeys"]
            self.metadata["sshKeys"] = ""
          end

          if !self.metadata["sshKeys"].empty?
            self.metadata["sshKeys"] += "\n"
          end

          # TODO: FIX: super wierd hack to 
          self.metadata["sshKeys"] += "#{key.strip}"
          # self.metadata["sshKeys"] += "#{username}:#{key.strip}"

          return self.metadata
        end

        def reload
          data = service.get_server(self.name, self.zone_name).body
          @attached_disks = nil # it is made to reload #attached_disks next time it will be called 
          self.merge_attributes(data)
          self
        end

        def save
          requires :name
          requires :machine_type
          requires :zone_name
          requires :disks

          self.add_ssh_key(self.username, self.public_key) if self.public_key

          options = {
              'machineType' => machine_type,
              'networkInterfaces' => network_interfaces,
              'disks' => disks,
              'metadata' => metadata,
              'tags' => tags
          }.delete_if {|key, value| value.nil?}

          response = service.insert_server(name, zone_name, options)

          operation = service.operations.new(response.body)
          operation.wait_for { ready? }

          data = service.backoff_if_unfound { service.get_server(self.name, self.zone_name).body }
          merge_attributes(data)

          self
        end

        def reset 
          requires :name, :zone_name
          response = service.reset_server(name, zone_name)
          service.operations.new(response.body)
        end
        alias_method :reboot, :reset


        def set_metadata(metadata = {}, options = {merge: true})
          requires :name, :zone_name
          if @metadata_fingerprint.nil? 
            raise "Server metadata should be Hash and have 'fingerprint' key.\n" +
                  "'fingerprint' key is returned after get_server request.\n" + 
                  "You can't call set_metadata on new instances. Have a good day."
          end
          response = service.set_metadata(name, zone_name, @metadata_fingerprint, metadata)
          service.operations.new(response.body)
        end

        def attach(disk, options = {})
          requires :name, :zone_name
          if disk.is_a?(Disk)
            response = service.attach_disk(self.name, disk.self_link, zone_name, options)
            service.operations.new(response.body)
          else
            raise 'Currently Server#attach method accepts only Disk object.'
          end
        end

        def device_name_for(disk)
          requires :disks
          p [:device_name_for, "self.disks", self.disks]
          disk_device_json = self.disks.find { |attached_disk| attached_disk['source'] == disk.self_link }
          device_name = disk_device_json['deviceName']
        end

        def detach(disk, options = {})
          requires :name, :zone_name
          if disk.is_a?(Disk)
            device_name = self.device_name_for(disk)
            response = service.detach_disk(self.name, zone_name, device_name)
            service.operations.new(response.body)
          else
            raise 'Currently Server#detach method accepts only Disk object.'
          end
        end

        def attached_disks
          requires :disks
          @attached_disks ||= self.disks.map do |disk|
            # we can work without parsing, but not now
            _, __, zone, name = disk['source'].match(/^https\:\/\/www\.googleapis\.com\/compute\/v1\/projects\/(.+)\/zones\/(.+)\/disks\/(.+)$/).to_a
            response = service.get_disk(name, zone)
            service.disks.new(response.body)
          end
        end

        # def external_ip
        #   requires :network_interfaces
        #   raise "Strange, but #{self.inspect} should have network_interfaces." if self.network_interfaces.empty?
        #   network_config = self.network_interfaces.find do |network| 
        #     network['accessConfigs'].find { |config| config['type'] == 'ONE_TO_ONE_NAT' }
        #   end
        #   network_config.nil? ? nil : network_config['natIP']
        # end

      end
    end
  end
end
