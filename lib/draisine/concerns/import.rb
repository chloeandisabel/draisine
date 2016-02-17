require "active_support/concern"

module Draisine
  module Concerns
    module Import
      extend ActiveSupport::Concern

      module ClassMethods
        # Doesn't update record if found
        def import_with_attrs(sf_id, attrs)
          find_or_initialize_by(salesforce_id: sf_id) do |model|
            model.salesforce_update_without_sync(attrs)
          end
        end

        # Does update record if found
        def import_or_update_with_attrs(sf_id, attrs, check_modstamp = false)
          find_or_initialize_by(salesforce_id: sf_id).tap do |model|
            model.salesforce_update_without_sync(attrs, check_modstamp)
          end
        end
      end

      def salesforce_update_without_sync(attributes, check_modstamp = false)
        salesforce_skipping_sync do
          modstamp = attributes["SystemModstamp"]
          own_modstamp = self.attributes["SystemModstamp"]
          if !check_modstamp || !modstamp || !own_modstamp || own_modstamp < modstamp
            salesforce_assign_attributes(attributes)
            save!
          end
        end
      end
    end
  end
end
