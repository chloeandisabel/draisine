module Draisine
  class JobBase < ActiveJob::Base
    rescue_from StandardError do |ex|
      Draisine.job_error_handler.call(ex, self, arguments)
      raise ex
    end
  end
end
