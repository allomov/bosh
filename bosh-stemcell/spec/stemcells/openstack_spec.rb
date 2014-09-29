require 'spec_helper'

describe 'OpenStack Stemcell', stemcell_image: true do
  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/infrastructure') do
      it { should contain('openstack') }
    end
  end

  context 'installed by image_openstack_qcow2 stage' do
    describe 'converts to qcow2 0.10 compat' do
      # environment is cleaned up inside rspec context
      stemcell_image = ENV['STEMCELL_IMAGE']

      subject do
        cmd = "qemu-img info #{File.join(File.dirname(stemcell_image), 'root.qcow2')}"
        `#{cmd}`
      end

      it { should include('compat: 0.10') }
    end
  end
end
