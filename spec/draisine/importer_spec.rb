require "spec_helper_ar"

describe Draisine::Importer do
  include_context "Salesforce stubs"

  let(:model_class) { Lead }
  let(:lead_type_map) do
    {
      "Id" => { type: "string" },
      "FirstName" => { type: "string" },
      "LastName" => { type: "string" }
    }
  end
  let(:leads) do
    [
      { "Id" => "A000", "FirstName" => "John", "LastName" => "Doe", "SomeGibberish" => "Unknown" },
      { "Id" => "A001", "FirstName" => "Alice", "LastName" => "Smith" },
      { "Id" => "A002", "FirstName" => "Bob", "LastName" => "Black" }
    ]
  end

  before(:each) do
    allow(Draisine).to receive(:salesforce_client) { sf_client }
    allow(Rails).to receive(:logger).and_return(Logger.new("/dev/null"))
    allow(sf_client).to receive(:materialize) {
      MaterializedModel.new(lead_type_map)
    }

    allow(sf_client).to receive(:query).and_return(
      Collection.new(leads.map { |attrs| MaterializedModelInstance.new(attrs) }),
      Collection.new([])
    )
  end

  subject { described_class.new(model_class) }

  it "creates a bunch of objects from response using Id column for salesforce_id" do
    expect do
      subject.import
    end.to change { model_class.count }.by(3)

    lead = model_class.find_by_salesforce_id("A000")
    expect(lead).not_to be_blank
    expect(lead.FirstName).to eq "John"
    expect(lead.LastName).to eq "Doe"
  end

  it "can be called repeatedly without troubles" do
    subject.import
    expect { subject.import }.not_to change { model_class.count }
  end

  it "can paginate over multiple response pages" do
    pg1 = Collection.new(leads[0..1].map { |attrs| MaterializedModelInstance.new(attrs) })
    pg2 = Collection.new(leads[2..-1].map { |attrs| MaterializedModelInstance.new(attrs) })
    pg3 = Collection.new([])
    allow(sf_client).to receive(:query).and_return(pg1, pg2, pg3)
    expect do
      subject.import
    end.to change { model_class.count }.by(3)
  end

  it "is resilient to errors" do
    attempts = 0
    allow(sf_client).to receive(:query) do
      if attempts < 3
        attempts += 1
        raise ArgumentError, "something terrible happened"
      end
      Collection.new([])
    end
    expect { subject.import }.not_to raise_error
  end

  it "fails eventually after repeated errors" do
    allow(sf_client).to receive(:query) do
      raise ArgumentError, "something terrible happened"
    end
    expect { subject.import }.to raise_error(ArgumentError)
  end

  describe "#import_new" do
    it "idempotently imports new records" do
      subject.import_new
      expect { subject.import_new }.not_to change { model_class.count }
    end
  end

  describe "#import_fields" do
    let!(:first) { model_class.import_with_attrs("A000", "FirstName" => "John") }
    let!(:second) { model_class.import_with_attrs("A001", "FirstName" => "Bob") }

    before do
      allow(sf_client).to receive(:fetch_multiple).and_return([
        MaterializedModelInstance.new("Id" => "A000", "FirstName" => "John", "LastName" => "Doe"),
        MaterializedModelInstance.new("Id" => "A001", "FirstName" => "Bob", "LastName" => "Smith")
      ])
    end

    it "takes existing records and updates them" do
      subject.import_fields(fields: ["LastName"])
      expect(first.reload.LastName).to eq("Doe")
      expect(second.reload.LastName).to eq("Smith")
    end

    it "only updates the provided fields" do
      second.update_column(:FirstName, "Nick")
      expect {
        subject.import_fields(fields: ["LastName"])
      }.not_to change { second.reload.FirstName }
    end
  end
end
