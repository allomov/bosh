module Bosh::Gce

  class Cloud < Bosh::Cloud
    include Helpers
    include Constants

    attr_reader   :registry
    attr_reader   :options
    attr_accessor :logger

    def initialize(options)
      @logger = Bosh::Clouds::Config.logger
      @options = options.dup.freeze

      validate_options

      # initialize_google_fog
      # initialize_registry
      
      # what is wrong with threading here ?
      # @metadata_lock = Mutex.new
    end

    def current_vm_id
    end


    def create_vm(agent_id, stemcell_id, resource_pool, network_spec, disk_locality = nil, environment = nil)
    end

    def delete_vm(instance_id)
    end

    def reboot_vm(instance_id)
    end

    def has_vm?(instance_id)
    end

    def create_disk(size, instance_id = nil)
    end

    def delete_disk(disk_id)
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
    end

    def create_stemcell(image_path, stemcell_properties)
    end

    def delete_stemcell(stemcell_id)
    end

    def set_vm_metadata(vm, metadata)
    end


  end
end
