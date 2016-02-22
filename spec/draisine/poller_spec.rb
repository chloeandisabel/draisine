require "spec_helper_ar"

describe Draisine::Poller do
  include_context "Salesforce stubs"

  subject { described_class }

  let(:model_class) { Lead }
  let(:start_date) { 10.minutes.ago }
  let(:end_date) { Time.now }

  before do
    salesforce_stub_out_leads!
    allow(sf_client).to receive(:get_updated_ids).and_return([])
    allow(sf_client).to receive(:get_deleted_ids).and_return([])
    allow(sf_client).to receive(:fetch_multiple).and_return([])
    allow(sf_client).to receive(:count).and_return(0)
  end

  describe ".poll" do
    it "imports new records" do
      allow(sf_client).to receive(:get_updated_ids).and_return(["A001"])
      allow(sf_client).to receive(:fetch_multiple).and_return([
        MaterializedModelInstance.new("FirstName" => "John", "Id" => "A001")
      ])

      expect {
        subject.poll(model_class: model_class, start_date: start_date, end_date: end_date, import_created: true)
      }.to change { model_class.count }.by(1)
      lead = model_class.last
      expect(lead.FirstName).to eq("John")
      expect(lead.salesforce_id).to eq("A001")
    end

    it "imports updated records" do
      lead = model_class.create_without_callbacks!(salesforce_id: "A001", FirstName: "Cole", SystemModstamp: 1.day.ago)
      allow(sf_client).to receive(:get_updated_ids).and_return(["A001"])
      allow(sf_client).to receive(:fetch_multiple).and_return([
        MaterializedModelInstance.new("FirstName" => "John", "Id" => "A001", "SystemModstamp" => Time.current)
      ])

      expect {
        subject.poll(model_class: model_class, start_date: start_date, end_date: end_date, import_updated: true)
      }.not_to change { model_class.count }
      lead.reload
      expect(lead.FirstName).to eq("John")
    end

    it "doesn't import updated records when flag is not set" do
      lead = model_class.create_without_callbacks!(salesforce_id: "A001", FirstName: "Cole", SystemModstamp: 1.day.ago)
      allow(sf_client).to receive(:get_updated_ids).and_return(["A001"])
      allow(sf_client).to receive(:fetch_multiple).and_return([
        MaterializedModelInstance.new("FirstName" => "John", "Id" => "A001", "SystemModstamp" => Time.current)
      ])

      expect {
        subject.poll(model_class: model_class, start_date: start_date, end_date: end_date, import_updated: false)
      }.not_to change { model_class.count }
      lead.reload
      expect(lead.FirstName).to eq("Cole")
    end

    it "removes deleted records" do
      lead = model_class.create_without_callbacks!(salesforce_id: "A001")
      allow(sf_client).to receive(:get_deleted_ids).and_return(["A001"])
      expect {
        subject.poll(model_class: model_class, start_date: start_date, end_date: end_date, import_deleted: true)
      }.to change { model_class.count }.by(-1)
    end

    it "doesn't remove deleted records when flag is not set" do
      lead = model_class.create_without_callbacks!(salesforce_id: "A001")
      allow(sf_client).to receive(:get_deleted_ids).and_return(["A001"])
      expect {
        subject.poll(model_class: model_class, start_date: start_date, end_date: end_date, import_deleted: false)
      }.to change { model_class.count }.by(0)
    end

    it "supports a different system modstamp polling mechanism" do
      expect(sf_client).to receive(:query).with(/SELECT Id FROM/).and_return([
        MaterializedModelInstance.new("Id" => "A000")
      ])
      expect(sf_client).to receive(:fetch_multiple).and_return([
        MaterializedModelInstance.new("Id" => "A000", "FirstName" => "John")
      ])
      expect { subject.poll(model_class: model_class, start_date: start_date, end_date: end_date, mechanism: :system_modstamp) }.to change { model_class.count }.by(1)
    end

    it "doesn't update the record if salesforce SystemModstamp is older than current SystemModstamp" do
      lead = model_class.create_without_callbacks!(salesforce_id: "A001", FirstName: "Cole", SystemModstamp: 1.day.ago)
      allow(sf_client).to receive(:get_updated_ids).and_return(["A001"])
      allow(sf_client).to receive(:fetch_multiple).and_return([
        MaterializedModelInstance.new("FirstName" => "John", "Id" => "A001", "SystemModstamp" => 3.days.ago)
      ])
      subject.poll(model_class: model_class, start_date: start_date, end_date: end_date, import_updated: true)
      expect(lead.reload.FirstName).to eq("Cole")
    end

    describe "results" do
      before do
        allow(sf_client).to receive(:count).and_return(0)
      end

      it "returns salesforce and db counters after running" do
        expect(sf_client).to receive(:count).and_return(42)
        model_class.create_without_callbacks!(salesforce_id: "A001")
        result = subject.poll(model_class: model_class, start_date: start_date, end_date: end_date)
        expect(result.salesforce_count).to eq(42)
        expect(result.db_count).to eq(1)
      end

      it "returns a number of salesforce created, updated and deleted records" do
        model_class.create_without_callbacks!(salesforce_id: "A001")
        model_class.create_without_callbacks!(salesforce_id: "A002")
        model_class.create_without_callbacks!(salesforce_id: "A003")
        allow(sf_client).to receive(:get_updated_ids).and_return(["A001", "A004"])
        allow(sf_client).to receive(:fetch_multiple).and_return([
          MaterializedModelInstance.new("FirstName" => "John", "Id" => "A001", "SystemModstamp" => Time.current),
          MaterializedModelInstance.new("FirstName" => "Jack", "Id" => "A004")
        ])
        allow(sf_client).to receive(:get_deleted_ids).and_return(["A002", "A003"])
        result = subject.poll(model_class: model_class, start_date: start_date, end_date: end_date, import_created: true, import_updated: true, import_deleted: true)
        expect(result.created_count).to eq(1)
        expect(result.updated_count).to eq(1)
        expect(result.deleted_count).to eq(2)
      end
    end
  end

  describe ".run_partition" do
    it "allows running a specific partition" do
      allow(sf_client).to receive(:get_updated_ids).and_return(["A001"])
      allow(sf_client).to receive(:fetch_multiple).and_return([
        MaterializedModelInstance.new("FirstName" => "John", "Id" => "A001")
      ])
      partition = Draisine::Partition.new(model_class, start_date, end_date, ["A001"])
      subject.run_partition(partition)
    end
  end
end
