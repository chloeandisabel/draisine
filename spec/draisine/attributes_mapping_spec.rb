require "spec_helper"

describe Draisine::AttributesMapping do
  let(:described_class) do
    Class.new do
      attr_accessor :first_name
      attr_accessor :last_name
      attr_accessor :CustomAttribute__c

      include Draisine::AttributesMapping
      self.salesforce_mapping = {
        'FirstName' => 'first_name',
        'LastName' => 'last_name'
      }
    end
  end

  subject { described_class.new }

  describe "#salesforce_assign_attributes" do
    it "assigns mapped attributes using the mapping" do
      subject.salesforce_assign_attributes({
        'FirstName' => 'Mark',
        'LastName' => 'Abramov'
      })
      expect(subject.first_name).to eq('Mark')
      expect(subject.last_name).to eq('Abramov')
    end

    it "assigns non-mapped attributes as is" do
      subject.salesforce_assign_attributes('CustomAttribute__c' => 1)
      expect(subject.CustomAttribute__c).to eq(1)
    end

    it "ignores attributes for which the setters don't exist" do
      expect {
        subject.salesforce_assign_attributes('Gibberish' => 123)
      }.not_to raise_error
    end
  end

  describe "#salesforce_reverse_mapped_attributes" do
    it "reverse-maps known mapped keys" do
      result = subject.salesforce_reverse_mapped_attributes({
        'first_name' => 'John',
        'last_name' => 'Doe'
      })
      expect(result).to eq({ 'FirstName' => 'John', 'LastName' => 'Doe' })
    end

    it "doesn't touch keys it doesn't know" do
      result = subject.salesforce_reverse_mapped_attributes({
        'Gibberish' => 123
      })
      expect(result).to eq('Gibberish' => 123)
    end
  end
end
