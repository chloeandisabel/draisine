require "active_support/concern"

module Draisine
  module Concerns
    module AttributesMapping
      extend ActiveSupport::Concern

      module ClassMethods
        attr_accessor :salesforce_mapping

        def salesforce_synced_attributes
          @salesforce_synced_attributes ||= salesforce_mapping.keys
        end

        def salesforce_reverse_mapping
          @salesforce_reverse_mapping ||= salesforce_mapping.map(&:reverse).to_h
        end
      end

      def salesforce_mapped_attributes(attributes, mapping = self.class.salesforce_mapping)
        attributes.slice(*mapping.keys).each_with_object({}) do |(key, value), acc|
          acc[mapping.fetch(key)] = value
        end
      end

      def salesforce_assign_attributes(attributes)
        salesforce_mapped_attributes(attributes.with_indifferent_access).each do |key, value|
          method_name = "#{key}="
          if respond_to?(method_name)
            value = Draisine::SalesforceComparisons.salesforce_cleanup(value)
            __send__(method_name, value)
          end
        end
      end

      def salesforce_reverse_mapped_attributes(attributes)
        salesforce_mapped_attributes(attributes, self.class.salesforce_reverse_mapping)
      end

      def salesforce_attributes
        salesforce_reverse_mapped_attributes(attributes)
          .with_indifferent_access
      end
    end
  end
end
