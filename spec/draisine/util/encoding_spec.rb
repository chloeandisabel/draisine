require "spec_helper"

describe Draisine::Encoding do
  describe ".convert_to_utf_and_sanitize" do
    it "replaces invalid entities" do
      bad_string = "\xE2".force_encoding("ASCII-8BIT")
      result = described_class.convert_to_utf_and_sanitize(bad_string)
      expect(result).to eq("?")
    end
  end
end
