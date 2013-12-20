require "spec_helper"
require "tempfile"
require "cloud"
require "logger"

describe Bosh::Google::Cloud do

  before(:all) do
    %w(client_email key_location project storage_access_key storage_secret
                    manual_ip region net_id manual_ip).each do |attribute|
      variable_name  = :"@#{attribute}"
      bosh_key_name  = "BOSH_GOOGLE_#{attribute.upcase}"
      variable_value = ENV[bosh_key_name] || raise("Missing #{bosh_key_name}")
      instance_varibale_set(variable_name, variable_value)
    end
  end

  subject(:cpi) do
    described_class.new(
      # TODO: simplify it 
      # client_email key_location project storage_access_key storage_secret
      'google' => {
        'compute' => {
          'client_email' => @client_email,
          'key_location' => @key_location,
          'project' => @project
        }, 
        'storage' => {
          'access_key' => @storage_access_key,
          'secret' => @storage_secret
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

  before do
    delegate = double("delegate", task_checkpoint: nil, logger: Logger.new(STDOUT))
    Bosh::Clouds::Config.configure(delegate)
  end

  before { Bosh::Registry::Client.stub(:new).and_return(double("registry").as_null_object) }

  before { @server_id = nil }

  after do
    if @server_id
      cpi.delete_vm(@server_id)
      cpi.has_vm?(@server_id).should be(false)
    end
  end

  before { @volume_id = nil }
  after { cpi.delete_disk(@volume_id) if @volume_id }

  def create_stemcell(stemcell_path)

    cpi.create_stemcell(stemcell_path) # unpacks and uploads stemcell file
    

  end

  def vm_lifecycle(stemcell_id, network_spec, disk_locality)
    @server_id = cpi.create_vm(
      "turnip",
      stemcell_id,
      { "instance_type" => "m1.small" } ,
      network_spec,
      disk_locality,
      { "key" => "value" }
    )

    @server_id.should_not be_nil

    cpi.has_vm?(@server_id).should be(true)

    metadata = {:deployment => 'deployment', :job => "openstack_cpi_spec", :index => "0"}
    cpi.set_vm_metadata(@server_id, metadata)

    @volume_id = cpi.create_disk(2048, @server_id)
    @volume_id.should_not be_nil

    cpi.attach_disk(@server_id, @volume_id)

    cpi.detach_disk(@server_id, @volume_id)

    metadata[:instance_id] = 'instance'
    metadata[:agent_id] = 'agent'
    metadata[:director_name] = 'Director'
    metadata[:director_uuid] = '6d06b0cc-2c08-43c5-95be-f1b2dd247e18'
    snapshot_id = cpi.snapshot_disk(@volume_id, metadata)
    snapshot_id.should_not be_nil

    cpi.delete_snapshot(snapshot_id)
  end

  describe "dynamic network" do
    let(:network_spec) do
      {
        "default" => {
          "type" => "dynamic",
          "cloud_properties" => {}
        }
      }
    end

    context "without existing disks" do
      it "should exercise the vm lifecycle" do
        vm_lifecycle(@stemcell_id, network_spec, [])
      end
    end

    context "with existing disks" do
      before { @existing_volume_id = cpi.create_disk(2048) }
      after { cpi.delete_disk(@existing_volume_id) if @existing_volume_id }

      it "should exercise the vm lifecycle" do
        vm_lifecycle(@stemcell_id, network_spec, [@existing_volume_id])
      end
    end
  end

  describe "manual network" do
    let(:network_spec) do
      {
        "default" => {
          "type" => "manual",
          "ip" => @manual_ip,
          "cloud_properties" => {
            "net_id" => @net_id
          }
        }
      }
    end

    context "without existing disks" do
      it "should exercise the vm lifecycle" do
        vm_lifecycle(@stemcell_id, network_spec, [])
      end
    end

    context "with existing disks" do
      before { @existing_volume_id = cpi.create_disk(2048) }
      after { cpi.delete_disk(@existing_volume_id) if @existing_volume_id }

      it "should exercise the vm lifecycle" do
        # Sometimes Quantum is too slow to release an IP address, so when we
        # spin up a new vm reusing the same IP it fails with a vm state error
        # but without any clue what the problem is (you should check the nova log).
        # This should be removed once we figure out how to deal with this situation.
        sleep(120)
        vm_lifecycle(@stemcell_id, network_spec, [@existing_volume_id])
      end
    end
  end
end
