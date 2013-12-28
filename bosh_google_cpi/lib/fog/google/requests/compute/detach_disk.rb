module Fog
  module Compute
    class Google

      class Mock

        def detach_disk(instance_name, device_name, zone_name, options = {})
          Fog::Mock.not_implemented
        end

      end

      class Real

        def detach_disk(instance_name, device_name, zone_name, options = {})

          api_method = @compute.instances.detach_disk
          parameters = {
            'project' => @project,
            'instance' => instance_name,
            'zone' => zone_name, 
            'deviceName' => device_name
          }

          result = self.build_result(api_method, parameters)
          response = self.build_response(result)
        end

      end

    end
  end
end
