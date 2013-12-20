require 'fog/core/model'

module Fog
  module Compute
    class Google

      class Operation < Fog::Model

        identity :name

        attribute :kind, :aliases => 'kind'
        attribute :id, :aliases => 'id'
        attribute :creation_timestamp, :aliases => 'creationTimestamp'
        attribute :zone_name, :aliases => 'zone'
        attribute :status, :aliases => 'status'
        attribute :status_message, :aliases => 'statusMessage'
        attribute :self_link, :aliases => 'selfLink'
        attribute :error, :aliases => 'error'

        def ready?
          self.status == DONE_STATE
        end

        def pending?
          self.status == PENDING_STATE
        end

        def reload
          requires :id

          data = collection.get(id, zone)

          new_attributes = data.attributes
          self.merge_attributes(new_attributes)
          self
        end

        PENDING_STATE = "PENDING"
        RUNNING_STATE = "RUNNING"
        DONE_STATE = "DONE"

      end
    end
  end
end
