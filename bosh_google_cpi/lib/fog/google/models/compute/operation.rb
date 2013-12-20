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
        attribute :progress, :aliases => 'progress'

        def ready?
          self.status == DONE_STATE
        end

        def pending?
          self.status == PENDING_STATE
        end

        def reload
          requires :name

          data = collection.get(name, zone_name)

          new_attributes = data.attributes

          self.merge_attributes(new_attributes)
          self
        end


        # wait until operation will have desired state
        def wait(target_state = :done)
          started_at  = Time.now
          default_timeout = 60 * 10

          loop do
            duration = Time.now - started_at

            if duration > default_timeout
              raise "Timed out waiting for #{name}##{id} operation to be #{target_state}."
            end

            self.reload

            yield(self) if block_given?

            break if target_state == state.downcase.to_sym

            sleep(1)
          end
        end


        PENDING_STATE = "PENDING"
        RUNNING_STATE = "RUNNING"
        DONE_STATE = "DONE"

      end
    end
  end
end
