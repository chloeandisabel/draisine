module Draisine
  class SoapDeleteJob < Draisine::JobBase
    def _perform(message)
      SoapHandler.delete(message)
    end
  end
end
