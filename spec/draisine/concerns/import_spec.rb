require "spec_helper_ar"

describe Draisine::Concerns::Import do
  let(:described_class) { Lead }

  describe ".import_with_attrs" do
    it "creates a record with corresponding attributes" do
      described_class.import_with_attrs("A000", FirstName: "John", LastName: "Cena")
      record = described_class.find_by_salesforce_id("A000")
      expect(record).to be_present
      expect(record.FirstName).to eq "John"
    end

    it "doesn't duplicate records with the same salesforce id" do
      described_class.import_with_attrs("A000", FirstName: "John", LastName: "Cena")
      expect do
        described_class.find_by_salesforce_id("A000")
      end.not_to change { described_class.count }
    end

    it "works with string keys too" do
      described_class.import_with_attrs("A000", "FirstName" => "John")
      record = described_class.find_by_salesforce_id("A000")
      expect(record).to be_present
      expect(record.FirstName).to eq "John"
    end

    it "ignores missing attributes" do
      expect do
        described_class.import_with_attrs("A000", Gibberish: "John")
        described_class.import_with_attrs("A001", "Gibberish" => "John")
      end.not_to raise_error
    end
  end
end
