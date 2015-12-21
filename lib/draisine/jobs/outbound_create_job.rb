module Draisine
  class OutboundCreateJob < Draisine::JobBase
    def perform(instance)
      instance.salesforce_outbound_create
    end
  end
end
