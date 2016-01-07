module Draisine
  class OutboundDeleteJob < Draisine::JobBase
    def perform(instance)
      instance.salesforce_outbound_delete
    end
  end
end
