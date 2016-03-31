module Draisine
  class OutboundUpdateJob < Draisine::JobBase
    def _perform(instance, changed_attributes)
      instance.salesforce_outbound_update(changed_attributes)
    end
  end
end
