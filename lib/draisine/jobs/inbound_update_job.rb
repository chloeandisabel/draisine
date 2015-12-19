module Draisine
  class InboundUpdateJob < ActiveJob::Base
    def perform(klass, attributes)
      klass.salesforce_inbound_update(attributes)
    end
  end
end
