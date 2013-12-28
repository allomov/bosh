module Bosh::Google

  class Cloud < Bosh::Cloud
    include Bosh::Google::Helpers
    include Bosh::Google::Constants
    include Bosh::Google::CommonHelpers

    attr_reader   :registry
    attr_reader   :options
    attr_accessor :logger
    attr_accessor :connection
    attr_accessor :compute
    attr_accessor :storage


    ##
    # Cloud initialization
    #
    # @param [Hash] options cloud options
    def initialize(options)
      @options = options.dup
      @logger  = Bosh::Clouds::Config.logger 


      validate_options
      initialize_registry
      # TODO: move it to helper
      # initialize_google_fog

      # TODO: what does it makes? 
      # @agent_properties  = @options["agent"] || {} 
      @google_properties = @options["google"]

      compute_params = {
        :provider => 'google',
        :google_client_email => @google_properties['compute']['client_email'],
        :google_key_location => @google_properties['compute']['key_location'],
        :google_project      => @google_properties['compute']['project']
      }

      
      begin
        @logger.info("Connecting to Compute...")
        @compute = Fog::Compute.new(compute_params)
      rescue Exception => e
        @logger.error(e)
        # TODO:  Ask to scpecify params ! or validations
        cloud_error("Unable to connect to the Google Compute API. Check task debug log for details.")
      end

      storage_params = {
        :provider => 'google',
        :google_storage_access_key_id => @google_properties['storage']['access_key'],
        :google_storage_secret_access_key => @google_properties['storage']['secret']
      }

      begin
        @logger.info("Connecting to Storage...")        
        @storage = Fog::Storage.new(storage_params)
      rescue Exception => e
        @logger.error(e)
        cloud_error("Unable to connect to the Google Storage Service API. Check task debug log for details.")
      end

      @metadata_lock = Mutex.new

    end


    ##
    # Get the vm_id of this host
    #
    # @return [String] opaque id later used by other methods of the CPI
    # TODO: how it should work ? 
    # def current_vm_id
    #   not_implemented(:current_vm_id)
    # end

    ##
    # Creates a stemcell
    #
    # @param [String] image_path path to an opaque blob containing the stemcell image
    # @param [Hash] cloud_properties properties required for creating this template
    #               specific to a CPI
    # @return [String] opaque id later used by {#create_vm} and {#delete_stemcell}
    # 
    # I assume here that image_path contains path to the file
    def create_stemcell(image_path, _ = nil)
      @logger.info("Creating stemcell from #{image_path}...")
      # TODO: maybe we don't need to generate new image every time ? maybe we can check check sum
      # TODO: check if we can push tar.gz
      with_thread_name("create_stemcell(#{image_path}...)") do
        begin
            @logger.info("Creating new image...")
            # stemcell_directory = generate_stemcell_directory_name
            stemcell_directory = @storage.directories.find { |d| d.key == 'bosh-stemcell-1' }
            # stemcell_directory = @storage.directories.find { |d| d.key == 'myveryownbucket_huehuehuehue' }
            
            # stemcell_directory = 'bosh-stemcell-1'
            # image_name     = stemcell_image_name(image_path)

            image_name = "disk.raw"
            # image_name = "clear_ubuntu.tar.gz"

            # If image_path is set to existing file, then 
            # from the remote location on a background job and store it in its repository.
            # Otherwise, unpack image to temp directory and upload to Glance the root image.

            # Dir.mktmpdir do |tmp_dir|
            #   @logger.info("Extracting stemcell file to `#{tmp_dir}'...")
            #   unpack_image(tmp_dir, image_path)
            #   image_file = File.join(tmp_dir, image_root_file)
            # end
            
            file = nil
            remote do
              # file = stemcell_directory.files.new
              # file.key  = image_name
              # file.body = File.open(image_path, 'r')
              # @logger.info("Uploading image file #{image_name} into Google Storage...")
              # file.save
              file = stemcell_directory.files.to_a.find { |f| f.key == image_name }
            end

            @logger.info("Create new image..")
            raw_disk_url = "https://storage.googleapis.com/#{stemcell_directory.key}/#{image_name}"
            image = compute.images.new(name: generate_stemcell_name(from: image_path), raw_disk: raw_disk_url)

            remote { image.save }

            # is it needed ??? 
            wait_resource(image, :ready)
            
            image.identity.to_s
        rescue => e
          @logger.error(e)
          raise e
        end
      end
    end

    ##
    # Deletes a stemcell
    #
    # @param [String] stemcell stemcell id that was once returned by {#create_stemcell}
    # @return [void]
    def delete_stemcell(stemcell_id)
      # TODO: do I need to remove blob here ?
      remote do 
        stemcell_image = find_by_identity(compute.images, stemcell_id)
        operation = stemcell_image.delete
        operation.wait
      end
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
    def create_vm(agent_id, stemcell_id, resource_pool,
                  networks = nil, disk_locality = nil, env = nil)
      with_thread_name("create_vm(#{agent_id}, ...)") do
        @logger.info("Creating new server...")
        remote do

          server_name  = "vm-#{generate_timestamp}"
          image        = remote { @compute.images.find  { |f| f.identity == stemcell_id } }
          machine_type = resource_pool["machine_type"] || resource_pool["instance_type"] || 'g1-small'
          zone_name    =  resource_pool["zone_name"] || 'us-central1-b'
          server = @compute.servers.bootstrap( name: server_name, 
                                               source_image: image.name, 
                                               zone_name: zone_name, 
                                               machine_type: machine_type)
          
          # is id a name or an id ????
          # server.id.to_s
          @logger.info("Server is created with #{server.identity.to_s} id...")
          server.identity.to_s
        end
      end

    end

    ##
    # Deletes a VM
    #
    # @param [String] vm vm id that was once returned by {#create_vm}
    # @return [void]
    def delete_vm(vm_id)
      remote do
        @logger.info("Removing VM with #{vm_id} id...")
        operation = find_server_by_identity(vm_id).delete
        operation.wait
        @logger.info("VM is removed...")
      end
    end

    ##
    # Checks if a VM exists
    #
    # @param [String] vm vm id that was once returned by {#create_vm}
    # @return [Boolean] True if the vm exists
    def has_vm?(vm_id)
      remote do
        @logger.info("Checking if there is VM with #{vm_id} id...")
        !!find_server_by_identity(vm_id)
      end
    end

    ##
    # Reboots a VM
    #
    # @param [String] vm vm id that was once returned by {#create_vm}
    # @param [Optional, Hash] CPI specific options (e.g hard/soft reboot)
    # @return [void]
    def reboot_vm(vm_id)
      remote do
        @logger.info("Rebooting VM with #{vm_id} id...")        
        operation = find_server_by_identity(vm_id).reboot
        operation.wait
      end
    end

    ##
    # Set metadata for a VM
    #
    # Optional. Implement to provide more information for the IaaS.
    #
    # @param [String] vm vm id that was once returned by {#create_vm}
    # @param [Hash] metadata metadata key/value pairs
    # @return [void]
    def set_vm_metadata(vm_id, metadata)
      remote do
        @logger.info("Set VM with #{vm_id} id metadata #{metadata.inspect}...")
        server = find_server_by_identity(vm_id)
        operation = server.set_metadata(metadata)
        operation.wait
      end
    end

    ##
    # Configures networking an existing VM.
    #
    # @param [String] vm vm id that was once returned by {#create_vm}
    # @param [Hash] networks list of networks and their settings needed for this VM,
    #               same as the networks argument in {#create_vm}
    # @return [void]
    def configure_networks(vm_id, networks)
      not_implemented(:configure_networks)
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
    def create_disk(size, vm_locality = nil)
      remote do
        @logger.info("Creating disk...")
        disk = compute.disks.new(name: "bosh-disk-#{generate_timestamp}", zone_name: 'us-central1-b', size_gb: (size / 1024).to_i)
        disk.save
        disk.identity.to_s
      end
    end

    ##
    # Deletes a disk
    # Will raise an exception if the disk is attached to a VM
    #
    # @param [String] disk disk id that was once returned by {#create_disk}
    # @return [void]
    def delete_disk(disk_id)
      remote do
        @logger.info("Removing disk with #{disk_id} id...")
        disk = find_by_identity(compute.disks, disk_id)
        operation = disk.delete
        operation.wait
      end
    end

    ##
    # Attaches a disk
    #
    # @param [String] vm vm id that was once returned by {#create_vm}
    # @param [String] disk disk id that was once returned by {#create_disk}
    # @return [void]
    def attach_disk(vm_id, disk_id)
      remote do
        @logger.info("Attaching disk with #{disk_id} id to VM with #{vm_id} id...")
        server = find_server_by_identity(vm_id)
        disk   = find_by_identity(compute.disks, disk_id)
        operation = server.attach(disk)
        operation.wait
      end
    end

    ##
    # Detaches a disk
    #
    # @param [String] vm vm id that was once returned by {#create_vm}
    # @param [String] disk disk id that was once returned by {#create_disk}
    # @return [void]
    def detach_disk(vm_id, disk_id)
      remote do 
        @logger.info("Detaching disk with #{disk_id} id to VM with #{vm_id} id...")
        server = find_server_by_identity(vm_id)
        disk = find_by_identity(compute.disks, disk_id)
        operation = server.detach(disk)
        operation.wait
      end
    end    

    # Take snapshot of disk
    # @param [String] disk_id disk id of the disk to take the snapshot of
    # @return [String] snapshot id
    def snapshot_disk(disk_id, metadata={})
      remote do
        @logger.info("Creating Snapshot for disk #{disk_id}")
        disk = find_by_identity(compute.disks, disk_id)
        snapshot_name = "bosh-snapshot-for-#{disk_id}-disk"
        snapshot_name = "#{snapshot_name[0..40]}-#{generate_timestamp}"
        snapshot = disk.create_snapshot(snapshot_name, "bosh snapshot for disk with #{disk_id} id. #{generate_timestamp}")
        snapshot.identity.to_s
      end
    end

    # Delete a disk snapshot
    # @param [String] snapshot_id snapshot id to delete
    def delete_snapshot(snapshot_id)
      remote do
        @logger.info("Removing Snapshot #{snapshot_id}")
        snapshot = find_by_identity(compute.snapshots, snapshot_id)
        operation = snapshot.delete
        operation.wait
      end
    end

    ##
    # List the attached disks of the VM.
    #
    # @param [String] vm_id is the CPI-standard vm_id (eg, returned from current_vm_id)
    #
    # @return [array[String]] list of opaque disk_ids that can be used with the
    # other disk-related methods on the CPI
    def get_disks(vm_id)
      @logger.info("Getting disks of VM with #{vm_id} id...")
      remote do
        server = find_server_by_identity(vm_id)
        # currently server.disks return hash with #attachedDisks object
        # https://www.googleapis.com/compute/v1/projects/project/zones/#{zone}/disks/#{disk}
        # server.disks.map { |disk| get_disk disk['source'] }
        server.attached_disks.map { |disk| disk.identity.to_s }
      end      
    end

  end
end
