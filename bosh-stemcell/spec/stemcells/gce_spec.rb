require 'spec_helper'

describe 'GCE Stemcell' do
  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/infrastructure') do
      it { should contain('gce') }
    end
  end
end
