module Draisine
  module SalesforceComparisons
    module_function

    def salesforce_equals?(value, other)
      value = salesforce_coerce(value)
      other = salesforce_coerce(other)

      return value == other if value.class != other.class

      case value
      when String
        normalize_string(value) == normalize_string(other)
      else
        value == other
      end
    end

    def salesforce_coerce(value)
      value = value.to_time.utc if value.respond_to?(:to_time) && value.to_time
      value
    end

    def normalize_string(string)
      string.gsub("\r\n", "\n")
    end
  end
end
