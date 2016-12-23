module Draisine
  class SoapDeleteJob < Draisine::JobBase
    def _perform(message)
      SoapHandler.new.delete(message)
    end
  end
end
