module Bosh
  module Director
    module Api
      class MultiCloudManager
        def create(properties)
          cloud_config = Bosh::Director::Api::CloudConfigManager.new.update(properties['properties'])
          cloud = Bosh::Director::Models::Cloud.new(
            name: properties['name'],
            type: properties['type'],
            endpoint: properties['endpoint'],
            # agent_properties: properties['endpoint'],
            cloud_config: cloud_config
          )
          cloud.save
        end

        def delete(cloud_id)
          cloud = Bosh::Director::Models::Cloud[instance_id]
          cloud.delete
        end

        def list(limit = 20)
          Bosh::Director::Models::Cloud.order(Sequel.desc(:id)).limit(limit).to_a
        end

        def latest
          list(1).first
        end

        private

        # def validate_manifest(cloud_config)
        #   deployment = Bosh::Director::DeploymentPlan::CloudPlanner.new(cloud_config)
        #   parser = Bosh::Director::DeploymentPlan::CloudManifestParser.new(deployment, Config.logger)
        #   parser.parse(cloud_config.manifest)
        # end
      end
    end
  end
end
