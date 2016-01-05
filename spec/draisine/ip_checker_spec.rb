require "spec_helper"

describe Draisine::IpChecker do
  subject { described_class.new(%w[127.0.0.1 192.168.0.1/24]) }

  describe "#check" do
    it "returns true if any of the ranges match input" do
      expect(subject.check('127.0.0.1')).to be_truthy
      expect(subject.check('192.168.0.24')).to be_truthy
      expect(subject.check('192.168.0.191')).to be_truthy
    end

    it "returns false if none of the ranges match input" do
      expect(subject.check('129.0.0.1')).to be_falsey
      expect(subject.check('192.169.0.24')).to be_falsey
      expect(subject.check('192.168.1.191')).to be_falsey
    end
  end
end
