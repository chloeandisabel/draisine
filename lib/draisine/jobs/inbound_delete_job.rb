module Draisine
  class InboundDeleteJob < Draisine::JobBase
    after_perform do |job|
      Draisine.job_callback.call(job, job.arguments.last, job.arguments)
    end

    def perform(class_name, salesforce_id)
      klass = class_name.constantize
      klass.salesforce_inbound_delete(salesforce_id)
    end
  end
end
