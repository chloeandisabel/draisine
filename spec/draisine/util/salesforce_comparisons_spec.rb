require "spec_helper"

describe Draisine::SalesforceComparisons do
  subject { described_class }

  describe "#salesforce_equals?" do
    it "compares strings without lines endings" do
      expect(subject.salesforce_equals?("ABC", "abc")).to be_falsey
      expect(subject.salesforce_equals?("ABC", "ABC")).to be_truthy
    end

    it "replaces emoji with spaces in compared strings" do
      expect(subject.salesforce_equals?("AAA 😬 AAA", "AAA AAA")).to be_truthy
      str1 = "Good evening and Happy Valentine's Day!\n\nI processed this return for a customer in December, but I have yet to receive it.  It has a tracking number, but hasn't been updated since December either.  If there is anything we can do to get this to me so I can get it to my customer ASAP, that would be awesome!  I feel badly that it's been almost two months.\n\nThank you!\n💙💛\nLaura Gazda\nMerchandiser"
      str2 = "Good evening and Happy Valentine's Day!\n\nI processed this return for a customer in December, but I have yet to receive it.  It has a tracking number, but hasn't been updated since December either.  If there is anything we can do to get this to me so I can get it to my customer ASAP, that would be awesome!  I feel badly that it's been almost two months.\n\nThank you!\n\nLaura Gazda\nMerchandiser"
      expect(subject.salesforce_equals?(str1, str2)).to be_truthy
    end

    it "ignores whitespace" do
      expect(subject.salesforce_equals?("ABC\r\n", "ABC\n")).to be_truthy
      expect(subject.salesforce_equals?("ABC ", "ABC")).to be_truthy
      expect(subject.salesforce_equals?("AAA       AAA", "AAA AAA")).to be_truthy
      expect(subject.salesforce_equals?("ABC\r\n", "ABC")).to be_truthy
    end

    it "ignores control symbols" do
      expect(subject.salesforce_equals?("hello\u0011", "hello")).to be_truthy
    end

    it "coerces different time classes" do
      time = Time.current
      time1 = DateTime.parse(time.iso8601)
      time2 = time
      expect(subject.salesforce_equals?(time1, time2)).to be_truthy
    end

    it "has 1s precision" do
      time = Time.current.round
      another = time + 0.001.seconds
      expect(time).not_to eq(another)
      expect(subject.salesforce_equals?(time, another)).to be_truthy
    end

    it "uses epsilon comparison for floats" do
      expect(subject.salesforce_equals?(1.01 + 0.99, 2.00)).to be_truthy
      expect(subject.salesforce_equals?(2, 1.01 + 0.99)).to be_truthy
      expect(subject.salesforce_equals?(2.00 + Draisine::SalesforceComparisons::EPSILON / 2, 2)).to be_truthy
      expect(subject.salesforce_equals?(2.00 + Draisine::SalesforceComparisons::EPSILON * 2, 2)).to be_falsey
    end

    it "doesn't try to coerce strings looking like numbers" do
      expect(subject.salesforce_equals?("10:00 +99:00", "10:00 +99:00")).to be_truthy
    end

    it "converts iso8601 strings into timestamps" do
      time = Time.current
      time1 = time.iso8601
      expect(time1).not_to eq(time)
      expect(subject.salesforce_equals?(time, time1)).to be_truthy
    end

    it "compares different types using normal equality" do
      expect(subject.salesforce_equals?(123, nil)).to be_falsey
      expect(subject.salesforce_equals?(123, 123)).to be_truthy
      expect(subject.salesforce_equals?(123, 456)).to be_falsey
    end
  end
end
