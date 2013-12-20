module Bosh::Agent
  class Infrastructure::Gce
    require 'bosh_agent/infrastructure/openstack/settings'
    require 'bosh_agent/infrastructure/openstack/registry'

    def load_settings
      Settings.new.load_settings
    end

    def get_network_settings(network_name, properties)
      Settings.new.get_network_settings(network_name, properties)
    end

  end
end
