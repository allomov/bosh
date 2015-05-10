module Bosh::Director::Models
  class Cloud < Sequel::Model(Bosh::Director::Config.db)

    has_one :cloud_config

    # def validate
    #   validates_presence [:state, :timestamp, :description]
    # end
  end
end
