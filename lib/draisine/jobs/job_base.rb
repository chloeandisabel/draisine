module Draisine
  class JobBase < ActiveJob::Base
    queue_as :salesforce_job

    rescue_from Exception do |ex|
      logger.error "#{ex.class}: #{ex}\n#{ex.backtrace.join("\n")}"

      if retry_attempt < retries_count
        @retry_attempt = retry_attempt + 1
        logger.error "Retrying (attempt #{retry_attempt})"
        retry_job
      else
        logger.error "Too many attempts, no more retries"
        Draisine.job_error_handler.call(ex, self, arguments)
        raise ex
      end
    end

    def self.logger
      Draisine.logger || super
    end

    def retries_count
      Draisine.job_retry_attempts
    end

    def retry_attempt
      @retry_attempt ||= 0
    end

    def serialize
      super.merge('_retry_attempt' => retry_attempt)
    end

    def deserialize(job_data)
      @retry_attempt = job_data.fetch('_retry_attempt', 0)
    end

    def logger
      self.class.logger
    end
  end
end
