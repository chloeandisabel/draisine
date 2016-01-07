module Draisine
  def self.parse_time(time_or_string)
    case time_or_string
    when Time, DateTime
      time_or_string
    when String
      Time.parse(time_or_string)
    else
      Time.parse(time_or_string.to_s)
    end
  rescue => e
    nil
  end
end
