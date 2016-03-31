module Draisine
  class OutboundCreateJob < Draisine::JobBase
    def _perform(instance)
      instance.salesforce_outbound_create
    end
  end
end
