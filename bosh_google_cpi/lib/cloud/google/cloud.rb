module Bosh::Gce

  class Cloud < Bosh::Cloud
    include Helpers
    include Constants

    attr_reader   :registry
    attr_reader   :options
    attr_accessor :logger
    attr_accessor :connection

    ##
    # Cloud initialization
    #
    # @param [Hash] options cloud options
    def initialize(options)
      @logger = Bosh::Clouds::Config.logger
      @options = options.dup.freeze
      # TODO : raise descriptive error if connection fails
      @connection = Fog::Compute.new({ :provider => "Google" }) 

      validate_options


      # initialize_google_fog
      # initialize_registry
      
      # what is wrong with threading here ?
      # @metadata_lock = Mutex.new
    end

    ##
    # Get the vm_id of this host
    #
    # @return [String] opaque id later used by other methods of the CPI    
    def current_vm_id
    end

    ##
    # Creates a stemcell
    #
    # @param [String] image_path path to an opaque blob containing the stemcell image
    # @param [Hash] cloud_properties properties required for creating this template
    #               specific to a CPI
    # @return [String] opaque id later used by {#create_vm} and {#delete_stemcell}
    def create_stemcell(image_path, stemcell_properties)
    end

    ##
    # Deletes a stemcell
    #
    # @param [String] stemcell stemcell id that was once returned by {#create_stemcell}
    # @return [void]
    def delete_stemcell(stemcell_id)
    end




    ##
    # Creates a VM - creates (and powers on) a VM from a stemcell with the proper resources
    # and on the specified network. When disk locality is present the VM will be placed near
    # the provided disk so it won't have to move when the disk is attached later.
    #
    # Sample networking config:
    #  {"network_a" =>
    #    {
    #      "netmask"          => "255.255.248.0",
    #      "ip"               => "172.30.41.40",
    #      "gateway"          => "172.30.40.1",
    #      "dns"              => ["172.30.22.153", "172.30.22.154"],
    #      "cloud_properties" => {"name" => "VLAN444"}
    #    }
    #  }
    #
    # Sample resource pool config (CPI specific):
    #  {
    #    "ram"  => 512,
    #    "disk" => 512,
    #    "cpu"  => 1
    #  }
    # or similar for EC2:
    #  {"name" => "m1.small"}
    #
    # @param [String] agent_id UUID for the agent that will be used later on by the director
    #                 to locate and talk to the agent
    # @param [String] stemcell stemcell id that was once returned by {#create_stemcell}
    # @param [Hash] resource_pool cloud specific properties describing the resources needed
    #               for this VM
    # @param [Hash] networks list of networks and their settings needed for this VM
    # @param [optional, String, Array] disk_locality disk id(s) if known of the disk(s) that will be
    #                                    attached to this vm
    # @param [optional, Hash] env environment that will be passed to this vm
    # @return [String] opaque id later used by {#configure_networks}, {#attach_disk},
    #                  {#detach_disk}, and {#delete_vm}
    def create_vm(agent_id, stemcell_id, resource_pool, network_spec, disk_locality = nil, environment = nil)
    end

    ##
    # Deletes a VM
    #
    # @param [String] vm vm id that was once returned by {#create_vm}
    # @return [void]
    def delete_vm(instance_id)
    end

    ##
    # Checks if a VM exists
    #
    # @param [String] vm vm id that was once returned by {#create_vm}
    # @return [Boolean] True if the vm exists
    def has_vm?(instance_id)
    end

    ##
    # Reboots a VM
    #
    # @param [String] vm vm id that was once returned by {#create_vm}
    # @param [Optional, Hash] CPI specific options (e.g hard/soft reboot)
    # @return [void]
    def reboot_vm(instance_id)
    end

    ##
    # Set metadata for a VM
    #
    # Optional. Implement to provide more information for the IaaS.
    #
    # @param [String] vm vm id that was once returned by {#create_vm}
    # @param [Hash] metadata metadata key/value pairs
    # @return [void]
    def set_vm_metadata(vm, metadata)
      # TODO: server = get_vm(vm)
      server.metadata["test"] = "foo"
    end

    ##
    # Creates a disk (possibly lazily) that will be attached later to a VM. When
    # VM locality is specified the disk will be placed near the VM so it won't have to move
    # when it's attached later.
    #
    # @param [Integer] size disk size in MB
    # @param [optional, String] vm_locality vm id if known of the VM that this disk will
    #                           be attached to
    # @return [String] opaque id later used by {#attach_disk}, {#detach_disk}, and {#delete_disk}
    def create_disk(size, instance_id = nil)
      disk = connection.disks.create({
        :name => 'foggydisk',
        :size_gb => 10,
        :zone_name => 'us-central1-a',
        :source_image => 'centos-6-v20130522',
      })

      # TODO: think if we need it 
      disk.wait_for { disk.ready? }

        # ???
        server = connection.servers.bootstrap params 

    end

    def delete_disk(disk_id)
      disk.destroy
    end

    def attach_disk(instance_id, disk_id)

    end

    def detach_disk(instance_id, disk_id)
    end

    def get_disks(vm_id)

    end

    def snapshot_disk(disk_id, metadata)

    end

    def delete_snapshot(snapshot_id)

    end

    def configure_networks(instance_id, network_spec)
      # TODO: find out how to use configuration
      connection.insert_network('my-private-network', '10.240.0.0/16')
    end





  end
end
