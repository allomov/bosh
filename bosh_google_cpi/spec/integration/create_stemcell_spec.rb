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
      # client_email key_location project storage_access_key storage_secret
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

  describe "Image upload based flow" do

    it "uploads image" do
      stemcell_id = cpi.create_stemcell(stemcell_path)
      # check if stemcell exists in google compute engine
      # cpi.delete_stemcell(stemcell_id)
      # check if stemcell doesn't exist in google compute engine
    end

  end
end
