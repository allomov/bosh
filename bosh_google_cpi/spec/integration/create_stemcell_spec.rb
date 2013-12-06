require "spec_helper"

describe Bosh::Google::Cloud do

  before(:all) do
    %w(client_email key_location project storage_access_key storage_secret).each do |attribute|
      variable_name  = :"@#{attribute}"
      bosh_key_name  = "BOSH_GOOGLE_#{attribute.upcase}"
      variable_value = ENV[bosh_key_name] || raise("Missing #{bosh_key_name}")
      instance_varibale_set(variable_name, variable_value)
    end
  end


  let(:image) { double("image", :id => "i-bar", :name => "i-bar") }
  let(:unique_name) { SecureRandom.uuid }

  before :each do
    @tmp_dir = Dir.mktmpdir
  end

  describe "Image upload based flow" do

    it "creates stemcell using a stemcell file" do

    end

  end
end
