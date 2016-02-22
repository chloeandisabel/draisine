module Draisine
  class Poller
    module Mechanisms
      require "draisine/poller/mechanisms/base"
      require "draisine/poller/mechanisms/default"
      require "draisine/poller/mechanisms/system_modstamp"
      require "draisine/poller/mechanisms/last_modified_date"

      MAP = {
        default: Mechanisms::Default,
        system_modstamp: Mechanisms::SystemModstamp,
        last_modified_date: Mechanisms::LastModifiedDate
      }

      def self.fetch(name)
        MAP.fetch(name)
      end
    end
  end
end
