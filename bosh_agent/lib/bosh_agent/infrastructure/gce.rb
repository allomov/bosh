module Bosh::Agent
  class Infrastructure::Gce
    require 'bosh_agent/infrastructure/gce/settings'
    require 'bosh_agent/infrastructure/gce/registry'

    def load_settings
      Settings.new.load_settings
    end

    def get_network_settings(network_name, properties)
      Settings.new.get_network_settings(network_name, properties)
    end

  end
end
