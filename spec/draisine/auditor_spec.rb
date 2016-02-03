require "spec_helper_ar"

describe Draisine::Auditor do
  include_context "Salesforce stubs"
  subject { described_class.new(Lead) }

  before(:each) do
    allow(Draisine).to receive(:salesforce_client).and_return(sf_client)
    allow(Lead).to receive(:salesforce_attributes).and_return(['FirstName'])
    allow(Lead).to receive(:salesforce_audited_attributes).and_return(['FirstName'])
    Lead.create_without_callbacks!(salesforce_id: 'A000', FirstName: 'Alice', updated_at: 1.month.ago, created_at: 1.month.ago)
    Lead.create_without_callbacks!(salesforce_id: 'A001', FirstName: 'Bob', updated_at: 1.month.ago, created_at: 1.month.ago)
    Lead.create_without_callbacks!(salesforce_id: 'A002', FirstName: 'Charlie', updated_at: 1.month.ago, created_at: 1.month.ago)
    Lead.create_without_callbacks!(salesforce_id: 'D000', FirstName: 'Don', updated_at: 1.month.ago, created_at: 1.month.ago)
    allow(sf_client).to receive(:get_updated_ids).and_return([])
    allow(sf_client).to receive(:get_deleted_ids).and_return([])
  end

  describe ".partition" do
    let(:start_date) { 1.day.ago }
    let(:end_date) { 10.minutes.ago }

    before do
      Lead.delete_all
      Lead.create_without_callbacks!(salesforce_id: 'A000')
      allow(sf_client).to receive(:get_updated_ids).and_return(['A000', 'A001'])
      allow(sf_client).to receive(:get_deleted_ids).and_return(['D000'])
    end

    it "produces partitions for updated ids and deleted ids" do
      partitions = described_class.partition(Lead, start_date, end_date)
      expect(partitions).to have(1).element
      partition = partitions.first
      expect(partition.updated_ids).to eq(['A000', 'A001'])
      expect(partition.deleted_ids).to eq(['D000'])
    end

    it "splits partitions if neccessary" do
      partitions = described_class.partition(Lead, start_date, end_date, 2)
      expect(partitions).to have(2).elements
      expect(partitions.flat_map(&:updated_ids).compact).to eq(['A000', 'A001'])
      expect(partitions.flat_map(&:deleted_ids).compact).to eq(['D000'])
    end
  end

  describe ".run" do
    it "returns successful result if no discrepancies were found" do
      result = described_class.run(Lead)
      expect(result).to be_success
    end

    it "returns success when records are deleted BOTH from salesforce and locally" do
      allow(sf_client).to receive(:get_deleted_ids).and_return(['D000'])
      lead = Lead.find_by_salesforce_id('D000')
      lead.salesforce_skipping_sync(&:destroy)
      result = described_class.run(Lead)
      expect(result).to be_success
      expect(result.discrepancies).to be_empty
    end

    it "returns failure when records are deleted from salesforce and kept locally" do
      allow(sf_client).to receive(:get_deleted_ids).and_return(['D000'])
      result = described_class.run(Lead)
      expect(result).not_to be_success
      expect(result.discrepancies).to have(1).element
      discrepancy = result.discrepancies[0]
      expect(discrepancy.type).to eq(:remote_delete_kept_locally)
      expect(discrepancy.salesforce_id).to eq('D000')
      expect(discrepancy.local_id).to be_present
      expect(discrepancy.local_type).to be_present
      expect(discrepancy.local_attributes).to be_present
    end

    it "returns failure when there are local records without salesforce_id" do
      lead = Lead.create_without_callbacks!({})
      result = described_class.run(Lead)
      expect(result).not_to be_success
      expect(result.discrepancies).to have(1).element
      discrepancy = result.discrepancies[0]
      expect(discrepancy.type).to eq(:local_record_without_salesforce_id)
      expect(discrepancy.local_id).to be_present
      expect(discrepancy.local_type).to be_present
      expect(discrepancy.local_attributes).to be_present
    end

    it "returns success when records updated in salesforce are updated to same values locally" do
      allow(sf_client).to receive(:get_updated_ids).and_return(["A000"])
      modstamp = Time.parse('2015-12-10')
      allow(sf_client).to receive(:fetch_multiple).and_return(Collection.new([
        MaterializedModelInstance.new({
          'FirstName' => 'Alice',
          'Id' => 'A000',
          'SystemModstamp' => modstamp
        })
      ]))
      result = described_class.run(Lead)
      expect(result).to be_success
    end

    it "returns failure when records from salesforce are missing locally" do
      allow(sf_client).to receive(:get_updated_ids).and_return(['A000'])
      modstamp = Time.parse('2015-12-10')
      allow(sf_client).to receive(:fetch_multiple).and_return(Collection.new([
        MaterializedModelInstance.new({
          'FirstName' => 'Elizabeth',
          'Id' => 'A000',
          'SystemModstamp' => modstamp
        })
      ]))
      lead = Lead.find_by_salesforce_id('A000')
      lead.salesforce_skipping_sync(&:destroy)
      result = described_class.run(Lead)
      expect(result).not_to be_success
      expect(result.discrepancies).to have(1).element
      discrepancy = result.discrepancies[0]
      expect(discrepancy.type).to eq(:remote_record_missing_locally)
      expect(discrepancy.salesforce_id).to eq('A000')
      expect(discrepancy.remote_attributes).to be_present
    end

    it "returns failure when records in salesforce and local copies do not match" do
      allow(sf_client).to receive(:get_updated_ids).and_return(['A000'])
      modstamp = Time.parse('2015-12-10')
      allow(sf_client).to receive(:fetch_multiple).and_return(Collection.new([
        MaterializedModelInstance.new({
          'FirstName' => 'Elizabeth',
          'Id' => 'A000',
          'SystemModstamp' => modstamp
        })
      ]))
      result = described_class.run(Lead)
      expect(result).not_to be_success
      expect(result.discrepancies).to have(1).element
      discrepancy = result.discrepancies[0]
      expect(discrepancy.type).to eq(:mismatching_records)
      expect(discrepancy.salesforce_id).to eq('A000')
      expect(discrepancy.remote_attributes).to be_present
      expect(discrepancy.local_id).to be_present
      expect(discrepancy.local_type).to be_present
      expect(discrepancy.local_attributes).to be_present
      expect(discrepancy.local_attributes['FirstName']).to eq('Alice')
      expect(discrepancy.remote_attributes['FirstName']).to eq('Elizabeth')
      expect(discrepancy.diff_keys).to eq(['FirstName'])
    end

    it "returns failure when local updates didn't go through to salesforce" do
      allow(sf_client).to receive(:get_updated_ids).and_return([])
      allow(sf_client).to receive(:fetch_multiple).and_return(Collection.new([
        MaterializedModelInstance.new({
          'FirstName' => 'Anne',
          'Id' => 'A000'
        })
      ]))
      lead = Lead.find_by_salesforce_id('A000')
      lead.touch
      result = described_class.run(Lead, 1.minute.ago, Time.current)
      expect(result).not_to be_success
      expect(result.discrepancies).to have_exactly(1).element
      discrepancy = result.discrepancies[0]
      expect(discrepancy.type).to eq(:mismatching_records)
      expect(discrepancy.salesforce_id).to eq('A000')
      expect(discrepancy.remote_attributes).to be_present
      expect(discrepancy.local_id).to be_present
      expect(discrepancy.local_type).to be_present
      expect(discrepancy.local_attributes).to be_present
      expect(discrepancy.local_attributes['FirstName']).to eq('Alice')
      expect(discrepancy.remote_attributes['FirstName']).to eq('Anne')
      expect(discrepancy.diff_keys).to eq(['FirstName'])
    end

    it "doesn't return failure when difference is in non-audited attributes" do
      allow(sf_client).to receive(:get_updated_ids).and_return(['A000'])
      modstamp = Time.parse('2015-12-10')
      allow(sf_client).to receive(:fetch_multiple).and_return(Collection.new([
        MaterializedModelInstance.new({
          'FirstName' => 'Alice',
          'LastName' => 'Reed',
          'Id' => 'A000',
          'SystemModstamp' => modstamp
        })
      ]))
      allow(Lead).to receive(:salesforce_synced_attributes).and_return(["FirstName", "LastName"])
      allow(Lead).to receive(:salesforce_audited_attributes).and_return(["FirstName"])
      result = described_class.run(Lead)
      expect(result).to be_success
    end
  end
end
