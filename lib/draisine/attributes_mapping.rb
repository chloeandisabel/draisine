require "active_support/concern"

module Draisine
  module AttributesMapping
    extend ActiveSupport::Concern

    module ClassMethods
      attr_accessor :salesforce_mapping

      def salesforce_reverse_mapping
        @salesforce_reverse_mapping ||= salesforce_mapping.map(&:reverse).to_h
      end
    end

    def salesforce_mapped_attributes(attributes, mapping = self.class.salesforce_mapping)
      attributes.each_with_object({}) do |(key, value), acc|
        mapped_key = mapping.fetch(key) { key }
        acc[mapped_key] = value
      end
    end

    def salesforce_assign_attributes(attributes)
      salesforce_mapped_attributes(attributes).each do |key, value|
        method_name = "#{key}="
        if respond_to?(method_name)
          __send__(method_name, value)
        end
      end
    end

    def salesforce_reverse_mapped_attributes(attributes)
      salesforce_mapped_attributes(attributes, self.class.salesforce_reverse_mapping)
    end
  end
end
