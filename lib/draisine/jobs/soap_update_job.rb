module Draisine
  class SoapUpdateJob < Draisine::JobBase
    def _perform(message)
      SoapHandler.new.update(message)
    end
  end
end
