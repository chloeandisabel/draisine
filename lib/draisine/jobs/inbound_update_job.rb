module Draisine
  class InboundUpdateJob < ActiveJob::Base
    def perform(class_name, attributes)
      klass = class_name.constantize
      klass.salesforce_inbound_update(attributes)
    end
  end
end
