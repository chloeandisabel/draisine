module Draisine
  class InboundUpdateJob < Draisine::JobBase
    after_perform do |job|
      Draisine.job_callback.call(job, job.arguments.last['Id'], job.arguments)
    end

    def perform(class_name, attributes)
      klass = class_name.constantize
      klass.salesforce_inbound_update(attributes)
    end
  end
end
