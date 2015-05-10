module Bosh
  module Cli
    class Cloud < Struct.new(:name, :type, :properties, :created_at)
      def initialize(attrs)
        self.name = attrs.fetch(:name)
        self.type = attrs.fetch(:type)
        self.endpoint = attrs.fetch(:endpoint)
        self.properties = attrs.fetch(:properties)
        self.created_at = attrs.fetch(:created_at)
      end
    end
  end
end
