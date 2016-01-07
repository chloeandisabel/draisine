require "spec_helper"

describe Draisine do
  describe ".parse_time" do
    it "returns time instances as is" do
      time = Time.current
      expect(described_class.parse_time(time)).to eq(time)
    end

    it "parses string time" do
      time = Time.current
      expect(described_class.parse_time(time.iso8601)).to be_within(1).of(time)
    end

    it "returns nil when it can't do anything" do
      expect(described_class.parse_time(nil)).to be_nil
      expect(described_class.parse_time("")).to be_nil
      expect(described_class.parse_time(0)).to be_nil
    end
  end
end
