module Draisine
  class OutboundCreateJob < ActiveJob::Base
    def perform(instance)
      instance.salesforce_outbound_create
    end
  end
end
