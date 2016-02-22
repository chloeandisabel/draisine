module Draisine
  module QueryMechanisms
    require "draisine/query_mechanisms/base"
    require "draisine/query_mechanisms/default"
    require "draisine/query_mechanisms/system_modstamp"
    require "draisine/query_mechanisms/last_modified_date"

    MAP = {
      default: Default,
      system_modstamp: SystemModstamp,
      last_modified_date: LastModifiedDate
    }

    def self.fetch(name)
      MAP.fetch(name)
    end
  end
end
