module Fog
  module Core
    module Assotiations

      def included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods

        def has_many(assotiation_name, options = {})
          # assotiation_model
          # create assotiation getter and setter
        end

        def has_one(assotiation_name, options = {})
        end

        def belongs_to(model_name, options = {})

        end

      end
    end
  end
end
