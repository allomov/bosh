require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class MultiCloudController < BaseController

      post '/', :consumes => :yaml do
        properties = Psych.load(request.body.string)
        Bosh::Director::Api::MultiCloudManager.new.create(properties)
        status(201)
      end

      get '/' do
        clouds = Bosh::Director::Api::MultiCloudManager.new.list
        json_encode(
          clouds.map do |cloud|
            {
              "name"       => cloud.name,
              "type"       => cloud.type,
              "endpoint"   => cloud.endpoint,
              "properties" => cloud.cloud_config.properties,
              "created_at" => cloud.created_at,
            }
          end
        )
      end

      delete '/:name' do |name|
        Bosh::Director::Api::MultiCloudManager.new.delete(name)
        status(201)
      end

    end
  end
end
