require "spec_helper_ar"

describe Draisine::Auditor do
  include_context "Salesforce stubs"
  let(:sf_client) { double(:salesforce_client) }

  subject { described_class.new(Lead) }

  before(:each) do
    allow(Draisine).to receive(:salesforce_client).and_return(sf_client)
    allow(Lead).to receive(:salesforce_attributes).and_return(['FirstName'])
    allow(Lead).to receive(:salesforce_audited_attributes).and_return(['FirstName'])
    Lead.create_without_callbacks!(salesforce_id: 'A000', FirstName: 'Alice')
    Lead.create_without_callbacks!(salesforce_id: 'A001', FirstName: 'Bob' )
    Lead.create_without_callbacks!(salesforce_id: 'A002', FirstName: 'Charlie')
    Lead.create_without_callbacks!(salesforce_id: 'D000', FirstName: 'Don' )
    allow(sf_client).to receive(:get_updated).and_return({
      'ids' => [],
      'latestDateCovered' => Time.now.iso8601
    })
    allow(sf_client).to receive(:get_deleted).and_return({
      'deletedRecords' => [],
      'latestDateCovered' => Time.now.iso8601
    })
  end

  describe "#run" do
    it "returns successful result if no discrepancies were found" do
      result = subject.run
      expect(result).to be_success
    end

    it "returns success when records are deleted BOTH from salesforce and locally" do
      allow(sf_client).to receive(:get_deleted).and_return({
        'deletedRecords' => [{'id' => 'D000', 'deletedDate' => '2015-11-01T00:00:00+00:00'}],
        'latestDateCovered' => Time.now.iso8601
      })
      lead = Lead.find_by_salesforce_id('D000')
      lead.salesforce_skipping_sync(&:destroy)
      result = subject.run
      expect(result).to be_success
      expect(result.discrepancies).to be_empty
    end

    it "returns failure when records are deleted from salesforce and kept locally" do
      allow(sf_client).to receive(:get_deleted).and_return({
        'deletedRecords' => [{'id' => 'D000', 'deletedDate' => '2015-11-01T00:00:00+00:00'}],
        'latestDateCovered' => Time.now.iso8601
      })
      result = subject.run
      expect(result).not_to be_success
      expect(result.discrepancies).to have(1).element
      discrepancy = result.discrepancies[0]
      expect(discrepancy.type).to eq(:remote_delete_kept_locally)
      expect(discrepancy.salesforce_id).to eq('D000')
      expect(discrepancy.local_attrs).to be_present
    end

    it "returns success when records updated in salesforce are updated to same values locally" do
      allow(sf_client).to receive(:get_updated).and_return({
        'ids' => ['A000'],
        'latestDateCovered' => Time.now.iso8601
      })
      modstamp = Time.parse('2015-12-10')
      allow(sf_client).to receive(:fetch_multiple).and_return(Collection.new([
        MaterializedModelInstance.new({
          'FirstName' => 'Alice',
          'Id' => 'A000',
          'SystemModstamp' => modstamp
        })
      ]))
      result = subject.run
      expect(result).to be_success
    end

    it "returns failure when records from salesforce are missing locally" do
      allow(sf_client).to receive(:get_updated).and_return({
        'ids' => ['A000'],
        'latestDateCovered' => Time.now.iso8601
      })
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
      result = subject.run
      expect(result).not_to be_success
      expect(result.discrepancies).to have(1).element
      discrepancy = result.discrepancies[0]
      expect(discrepancy.type).to eq(:remote_record_missing_locally)
      expect(discrepancy.salesforce_id).to eq('A000')
      expect(discrepancy.remote_attrs).to be_present
    end

    it "returns failure when records in salesforce and local copies do not match" do
      allow(sf_client).to receive(:get_updated).and_return({
        'ids' => ['A000'],
        'latestDateCovered' => Time.now.iso8601
      })
      modstamp = Time.parse('2015-12-10')
      allow(sf_client).to receive(:fetch_multiple).and_return(Collection.new([
        MaterializedModelInstance.new({
          'FirstName' => 'Elizabeth',
          'Id' => 'A000',
          'SystemModstamp' => modstamp
        })
      ]))
      result = subject.run
      expect(result).not_to be_success
      expect(result.discrepancies).to have(1).element
      discrepancy = result.discrepancies[0]
      expect(discrepancy.type).to eq(:mismatching_records)
      expect(discrepancy.salesforce_id).to eq('A000')
      expect(discrepancy.remote_attrs).to be_present
      expect(discrepancy.local_attrs).to be_present
      expect(discrepancy.local_attrs['FirstName']).to eq('Alice')
      expect(discrepancy.remote_attrs['FirstName']).to eq('Elizabeth')
      expect(discrepancy.diff_keys).to eq(['FirstName'])
    end

    it "doesn't return failure when difference is in non-audited attributes" do
      allow(sf_client).to receive(:get_updated).and_return({
        'ids' => ['A000'],
        'latestDateCovered' => Time.now.iso8601
      })
      modstamp = Time.parse('2015-12-10')
      allow(sf_client).to receive(:fetch_multiple).and_return(Collection.new([
        MaterializedModelInstance.new({
          'FirstName' => 'Alice',
          'LastName' => 'Reed',
          'Id' => 'A000',
          'SystemModstamp' => modstamp
        })
      ]))
      allow(Lead).to receive(:salesforce_synced_attributes).and_return([:FirstName, :LastName])
      allow(Lead).to receive(:salesforce_audited_attributes).and_return([:FirstName])
      result = subject.run
      expect(result).to be_success
    end
  end
end
