require "spec_helper"

describe Bosh::Google::Cloud do

  before(:all) do
    @config = {}
    %w(client_email key_location project storage_access_key storage_secret).each do |attribute|
      variable_name  = :"@#{attribute}"
      bosh_key_name  = "BOSH_GOOGLE_#{attribute.upcase}"
      variable_value = ENV[bosh_key_name] || raise("Missing #{bosh_key_name}")
      @config[attribute.to_sym] = variable_value
    end
  end

  before do
    delegate = double("delegate", task_checkpoint: nil, logger: Logger.new(STDOUT))
    Bosh::Clouds::Config.configure(delegate)
  end


  subject(:cpi) do
    described_class.new(
      # TODO: simplify it 
      'google' => {
        'compute' => {
          'client_email' => @config[:client_email],
          'key_location' => @config[:key_location],
          'project' => @config[:project]
        }, 
        'storage' => {
          'access_key' => @config[:storage_access_key],
          'secret' => @config[:storage_secret]
        },
        "endpoint_type" => "publicURL",
        "default_key_name" => "some_secret",
        "default_security_groups" => ["default"]
      },
      "registry" => {
        "endpoint" => "fake",
        "user" => "fake",
        "password" => "fake"
      }
    )
  end

  # download stemcell and place it in ./tmp/stemcells folder 
  let(:stemcell_path) { ENV['BOSH_GOOGLE_STEMCELL_PATH'] || './tmp/stemcell.tar.gz' }

  describe "VM" do

    it "lifecircle" do
      # stemcell_id = cpi.create_stemcell(stemcell_path)

      image = cpi.compute.images.find { |image| image.name == 'debian-7-wheezy-v20131120' }
      stemcell_id = image.identity.to_s

      vm_id = cpi.create_vm('agent_id', stemcell_id, {'machine_type' => 'g1-small', 'zone_name' => 'us-central1-b'})
      # check if VM exists 
      cpi.has_vm?(vm_id).should be_true

      cpi.set_vm_metadata(vm_id, { metadata: 'Hodor!' })
      # check VM metadata
      
      cpi.reboot_vm(vm_id)
      # check if rebooted 

      disk_id = cpi.create_disk(10 * 1024)

      cpi.attach_disk(vm_id, disk_id)
      cpi.detach_disk(vm_id, disk_id)

      cpi.delete_disk(disk_id)

      cpi.delete_vm(vm_id)

      # cpi.delete_stemcell(stemcell_id)
      # check if stemcell doesn't exist in google compute engine      
    end

  end
end
