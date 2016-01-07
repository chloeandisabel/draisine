module Draisine
  class InboundDeleteJob < Draisine::JobBase
    def perform(class_name, salesforce_id)
      klass = class_name.constantize
      klass.salesforce_inbound_delete(salesforce_id)
    end
  end
end
