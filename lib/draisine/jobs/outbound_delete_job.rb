module Draisine
  class OutboundDeleteJob < Draisine::JobBase
    def _perform(instance)
      instance.salesforce_outbound_delete
    end
  end
end
