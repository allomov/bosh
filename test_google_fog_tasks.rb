require 'fog'

FogStruct = Struct.new(:compute, :storage)

class GoogleEngine
  include Singleton 
  attr_accessor :fog

  def initialize

    @google_properties = {
      "client_email" => "129630636471-mhb4dbhljlga73sbp1nhjg0svdqovpvu@developer.gserviceaccount.com",
      "key_location" => "~/google-engine-key.p12",
      "project"      => "idyllic-physics-408",
      "storage" => {
        "access_key" => 'GOOGFRXWWWO5GU7ECW6G', 
        'secret' => 'T7Pfx/c06+y1yxdvo6NDKBd5WrXXWMM+CUtxZEbr'
      }
    }
    storage_params = {
      :provider => 'google',
      :google_storage_access_key_id => @google_properties['storage']['access_key'],
      :google_storage_secret_access_key => @google_properties['storage']['secret']
    }
    compute_params = {
      :provider => 'google',
      :google_client_email => @google_properties['compute']['client_email'],
      :google_key_location => @google_properties['compute']['key_location'],
      :google_project      => @google_properties['compute']['project'],
    }


    self.fog = FogStruct.new(Fog::Copmute.new(params), Fog::Storage.new(storage_params))
  end

  def self.fog
    self.instance.fog
  end
end 

GE = GoogleEngine





def create_stemcell(image_path, cloud_properties)
  # Add your file to Google Cloud Storage.
  # - The bucket must be located in the United States.
  # - The bucket must be a _standard availability bucket_ instead of a durable reduced availability (DRA) bucket.
  # - You must have write access to the bucket to add your image file and write or read access to access the file.
  storage = GE.fog.storage
  compute = GE.fog.compute

  id = (rand*10).to_s.gsub('.', '')
  
  bucket_name = "bosh-fake-bucket"
  object_name = "bosh-fake-stemcell-image-#{id}"
  # try to get_bucket ?
  storage.put_bucket(bucket_name, 'LocationConstraint' => 'US', 'x-amz-acl' => 'public-read') # acl ?

  image_file = File.open(File.join(File.dirname(__FILE__), 'tmp', 'root.img'), 'r')
  storage.put_object(bucket_name, object_name, image_file)

  compute

end 







current_vm_id
create_stemcell
delete_stemcell
create_vm
delete_vm
has_vm?
reboot_vm
set_vm_metadata
configure_networks
create_disk
delete_disk
attach_disk
snapshot_disk
delete_snapshot
detach_disk
get_disks