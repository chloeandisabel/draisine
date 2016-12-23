module Draisine
  module Encoding
    def self.convert_to_utf_and_sanitize(string)
      string.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
    end
  end
end
