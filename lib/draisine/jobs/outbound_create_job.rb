module Draisine
  class OutboundCreateJob < Draisine::JobBase
    after_perform do |job|
      Draisine.job_callback.call(job,
        job.arguments.first.try(:salesforce_id), job.arguments)
    end

    def perform(instance)
      instance.salesforce_outbound_create
    end
  end
end
