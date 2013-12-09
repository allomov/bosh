require "spec_helper"

describe Bosh::Google::Cloud do

  before(:all) do
    @config = {}
    %w(client_email key_location project storage_access_key storage_secret).each do |attribute|
      variable_name  = :"@#{attribute}"
      bosh_key_name  = "BOSH_GOOGLE_#{attribute.upcase}"
      variable_value = ENV[bosh_key_name] || raise("Missing #{bosh_key_name}")
      @config[variable_name] = variable_value
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

  # download stemcell and place it in ./tmp/stemcells folder 
  let(:stemcell_path) { ENV['BOSH_GOOGLE_STEMCELL_PATH'] || './tmp/stemcell.tar.gz' }



  before :each do
    @tmp_dir = Dir.mktmpdir
  end

  describe "Image upload based flow" do

    it "uploads image" do
      cpi.create_stemcell(stemcell_path)
    end

  end
end
