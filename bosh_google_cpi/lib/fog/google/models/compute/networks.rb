require 'fog/core/collection'

module Fog
  module Compute
    class Google 
      class Networks < Fog::Collection

        model Fog::Compute::Network

        def all(filter = {})
          data = service.list_networks.body["items"] || []
          load(data)
        end

      end
    end
  end
end
