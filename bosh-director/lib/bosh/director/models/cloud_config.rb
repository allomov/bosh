module Bosh
  module Director
    module Models
      class CloudConfig < Sequel::Model(Bosh::Director::Config.db)
        one_to_one :cloud

        def before_create
          self.created_at ||= Time.now
        end

        def manifest=(cloud_config_hash)
          self.properties = Psych.dump(cloud_config_hash)
        end

        def manifest
          Psych.load properties
        end
      end
    end
  end
end
