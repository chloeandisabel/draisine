module Draisine
  class OutboundDeleteJob < Draisine::JobBase
    after_perform do |job|
      Draisine.job_callback.call(job,
        job.arguments.first.try(:salesforce_id), job.arguments)
    end

    def perform(instance)
      instance.salesforce_outbound_delete
    end
  end
end
