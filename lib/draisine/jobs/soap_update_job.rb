module Draisine
  class SoapUpdateJob < Draisine::JobBase
    def _perform(message)
      SoapHandler.update(message)
    end
  end
end
