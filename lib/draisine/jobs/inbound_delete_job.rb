module Draisine
  class InboundDeleteJob < ActiveJob::Base
    def perform(klass, salesforce_id)
      klass.salesforce_inbound_delete(salesforce_id)
    end
  end
end
