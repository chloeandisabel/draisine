require "spec_helper"

describe Draisine::Concerns::AttributesMapping do
  let(:described_class) do
    Class.new do
      attr_accessor :first_name
      attr_accessor :last_name
      attr_accessor :CustomAttribute__c

      include Draisine::Concerns::AttributesMapping
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

    it "doesn't assign non-mapped attributes" do
      subject.salesforce_assign_attributes('CustomAttribute__c' => 1)
      expect(subject.CustomAttribute__c).to be_nil
    end

    it "ignores attributes for which the setters don't exist" do
      expect {
        subject.salesforce_assign_attributes('Gibberish' => 123)
      }.not_to raise_error
    end

    it "works when assigning symbol-keyed attributes too" do
      subject.salesforce_assign_attributes(FirstName: 'Mark')
      expect(subject.first_name).to eq('Mark')
    end

    it "cleans up utf strings" do
      expect {
        subject.salesforce_assign_attributes(FirstName: "\xFFMark\xFF")
      }.not_to raise_error
      expect(subject.first_name =~ /Mark/).to be_truthy
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

    it "ignores keys it doesn't know" do
      result = subject.salesforce_reverse_mapped_attributes({
        'first_name' => 'John',
        'Gibberish' => 123
      })
      expect(result).to eq('FirstName' => 'John')
    end
  end
end
