module Draisine
  class OutboundUpdateJob < Draisine::JobBase
    after_perform do |job|
      Draisine.job_callback.call(job,
        job.arguments.first.try(:salesforce_id), job.arguments)
    end

    def perform(instance, changed_attributes)
      instance.salesforce_outbound_update(changed_attributes)
    end
  end
end
