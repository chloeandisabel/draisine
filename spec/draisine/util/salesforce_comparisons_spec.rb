require "spec_helper"

describe Draisine::SalesforceComparisons do
  subject { described_class }

  describe "#salesforce_equals?" do
    it "compares strings without lines endings" do
      expect(subject.salesforce_equals?("ABC", "abc")).to be_falsey
      expect(subject.salesforce_equals?("ABC", "ABC")).to be_truthy
      expect(subject.salesforce_equals?("ABC ", "ABC")).to be_falsey
      expect(subject.salesforce_equals?("ABC\r\n", "ABC\n")).to be_truthy
      expect(subject.salesforce_equals?("ABC\r\n", "ABC")).to be_falsey
    end

    it "coerces different time classes" do
      time = Time.current
      time1 = DateTime.parse(time.iso8601)
      time2 = time
      expect(subject.salesforce_equals?(time1, time2)).to be_truthy
    end

    it "has 1s precision" do
      time = Time.current
      another = time + 0.001.seconds
      expect(time).not_to eq(another)
      expect(subject.salesforce_equals?(time, another)).to be_truthy
    end

    it "doesn't try to coerce strings looking like numbers" do
      expect(subject.salesforce_equals?("10:00 +99:00", "10:00 +99:00")).to be_truthy
    end

    it "compares different types using normal equality" do
      expect(subject.salesforce_equals?(123, nil)).to be_falsey
      expect(subject.salesforce_equals?(123, 123)).to be_truthy
      expect(subject.salesforce_equals?(123, 456)).to be_falsey
    end
  end
end
