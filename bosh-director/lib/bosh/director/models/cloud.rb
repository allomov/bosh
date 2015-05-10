module Bosh::Director::Models
  class Cloud < Sequel::Model(Bosh::Director::Config.db)

    one_to_one :cloud_config
    one_to_many :stemcells
    many_to_many :deployments

    # def validate
    #   validates_presence [:state, :timestamp, :description]
    # end
  end
end
