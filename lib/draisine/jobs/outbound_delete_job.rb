module Draisine
  class OutboundDeleteJob < ActiveJob::Base
    def perform(instance)
      instance.salesforce_outbound_delete
    end
  end
end
