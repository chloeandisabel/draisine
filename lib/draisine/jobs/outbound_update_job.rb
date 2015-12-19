module Draisine
  class OutboundUpdateJob < ActiveJob::Base
    def perform(instance, changed_attributes)
      instance.salesforce_outbound_update(changed_attributes)
    end
  end
end
