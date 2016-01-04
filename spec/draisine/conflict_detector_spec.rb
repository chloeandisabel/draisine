require "spec_helper_ar"

describe Draisine::ConflictDetector do
  include_context "Salesforce stubs"

  before do
    salesforce_stub_out_leads!
  end

  let(:model) {
    Lead.create_without_callbacks!({
      salesforce_id: 'A001',
      FirstName: 'John',
      LastName: 'Snow'
    })
  }

  let(:attrs) { ['FirstName', 'LastName'] }

  describe "#conflict_type" do
    it "returns :no_conflict when two records have the same attributes" do
      remote_model = MaterializedModelInstance.new('Id' => 'A001', 'FirstName' => 'John', 'LastName' => 'Snow')
      subject = described_class.new(model, remote_model, attrs)
      expect(subject.conflict_type).to eq(:no_conflict)
    end

    it "returns :no_conflict when two records have differences in the attributes that aren't checked" do
      remote_model = MaterializedModelInstance.new('Id' => 'A001', 'FirstName' => 'John', 'LastName' => 'Cena')
      subject = described_class.new(model, remote_model, ['FirstName'])
      expect(subject.conflict_type).to eq(:no_conflict)
    end

    it "returns :mismatching_records when two records have different attributes" do
      remote_model = MaterializedModelInstance.new('Id' => 'A001', 'FirstName' => 'Sansa', 'LastName' => 'Stark')
      subject = described_class.new(model, remote_model, attrs)
      expect(subject.conflict_type).to eq(:mismatching_records)
    end

    it "returns :local_record_missing when local record is nil" do
      remote_model = MaterializedModelInstance.new('Id' => 'A001', 'FirstName' => 'Sansa', 'LastName' => 'Stark')
      subject = described_class.new(nil, remote_model, attrs)
      expect(subject.conflict_type).to eq(:local_record_missing)
    end

    it "returns :remote_record_missing when remote record is nil" do
      subject = described_class.new(model, nil, attrs)
      expect(subject.conflict_type).to eq(:remote_record_missing)
    end

    it "returns :no_conflict when both records are nil" do
      subject = described_class.new(nil, nil, attrs)
      expect(subject.conflict_type).to eq(:no_conflict)
    end
  end

  describe "#diff" do
    it "has diff for local and remote records" do
      remote_model = MaterializedModelInstance.new('Id' => 'A001', 'FirstName' => 'John', 'LastName' => 'Cena')
      subject = described_class.new(model, remote_model, ['FirstName', 'LastName'])
      diff = subject.diff
      expect(diff.unchanged).to eq(['FirstName'])
      expect(diff.changed).to eq(['LastName'])
    end
  end
end
