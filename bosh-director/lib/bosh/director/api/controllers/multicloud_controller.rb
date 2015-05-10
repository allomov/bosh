require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class MultiCloudController < BaseController

      post '/', :consumes => :yaml do
        properties = request.body.string
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
              "properties" => cloud.cloud_config.properties,
              "created_at" => cloud.created_at,
            }
          end
        )
      end

      delete '/:id' do |id|
        Bosh::Director::Api::MultiCloudManager.new.delete(id)
        status(201)
      end

    end
  end
end
