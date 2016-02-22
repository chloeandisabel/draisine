require "spec_helper_ar"

describe Draisine::Partitioner do
  include_context "Salesforce stubs"

  describe ".partition" do
    let(:start_date) { 1.day.ago }
    let(:end_date) { 10.minutes.since }

    before do
      allow(Draisine).to receive(:salesforce_client).and_return(sf_client)
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

    it "includes unpersisted records ids" do
      lead = Lead.create_without_callbacks!(salesforce_id: '')
      partition = described_class.partition(Lead, start_date, end_date).first
      expect(partition.unpersisted_ids).to eq([lead.id])
    end

    it "still returns a partition for zero updated / deleted ids" do
      Lead.delete_all
      allow(sf_client).to receive(:get_updated_ids).and_return([])
      allow(sf_client).to receive(:get_deleted_ids).and_return([])
      partitions = described_class.partition(Lead, start_date, end_date)
      partition = partitions.first
      expect(partition).to be_a(Draisine::Partition)
    end
  end
end
