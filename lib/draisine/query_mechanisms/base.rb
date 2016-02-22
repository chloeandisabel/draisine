module Draisine
  module QueryMechanisms
    class Base
      attr_reader :model_class, :client
      def initialize(model_class, client)
        @model_class = model_class
        @client = client
      end

      def salesforce_object_name
        model_class.salesforce_object_name
      end
    end
  end
end
