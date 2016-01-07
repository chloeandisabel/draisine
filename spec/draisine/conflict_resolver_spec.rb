require "spec_helper_ar"

describe Draisine::ConflictResolver do
  include_context "Salesforce stubs"

  let(:salesforce_id) { 'A001' }
  let(:lead) {
    Lead.create_without_callbacks!({
      salesforce_id: salesforce_id,
      FirstName: 'John',
      LastName: 'Snow'
    })
  }
  subject { described_class.new(lead.class, sf_client, salesforce_id) }

  before(:each) do
    salesforce_stub_out_leads!
    lead

    allow(sf_client).to receive(:find).with('Lead', salesforce_id).
      and_return(MaterializedModelInstance.new({
        'Id' => salesforce_id,
        'FirstName' => 'Sansa',
        'LastName' => 'Stark'
      }))
  end

  describe "#conflict?" do
    it "returns false if remote model and local model are the same" do
      expect(sf_client).to receive(:find).with('Lead', salesforce_id).
        and_return(MaterializedModelInstance.new({
          'Id' => salesforce_id,
          'FirstName' => 'John',
          'LastName' => 'Snow'
        }))

      expect(subject.conflict?).to be_falsey
    end

    it "returns true if remote model has different attributes to local model" do
      expect(subject.conflict?).to be_truthy
    end

    it "returns true if remote model doesn't exist" do
      allow(subject).to receive(:remote_model).and_return(nil)
      expect(subject.conflict?).to be_truthy
    end

    it "returns true if local model doesn't exist" do
      expect(sf_client).to receive(:find).with('Lead', salesforce_id).
        and_return(MaterializedModelInstance.new({
          'Id' => salesforce_id,
          'FirstName' => 'John',
          'LastName' => 'Snow'
        }))
      lead.delete # no callbacks
      expect(subject.conflict?).to be_truthy
    end

    it "returns false if both local and remote model don't exist" do
      allow(subject).to receive(:remote_model).and_return(nil)
      lead.delete
      expect(subject.conflict?).to be_falsey
    end
  end

  describe "#remote_pull" do
    it "pulls the remote record and updates all local fields" do
      subject.remote_pull
      lead.reload
      expect(lead.FirstName).to eq('Sansa')
      expect(lead.LastName).to eq('Stark')
    end

    it "creates a record if need be" do
      lead.delete # skip callbacks
      expect(lead.class.exists?(salesforce_id: salesforce_id)).to be_falsey
      subject.remote_pull
      expect(lead.class.exists?(salesforce_id: salesforce_id)).to be_truthy
    end

    it "doesn't trigger salesforce sync" do
      expect(sf_client).not_to receive(:http_patch)
      subject.remote_pull
    end
  end

  describe "#remote_push" do
    it "pushes the local record attributes into salesforce" do
      expect(sf_client).to receive(:http_patch)
      allow(sf_client).to receive(:http_get).and_return(double(body: { SystemModstamp: Time.now }.to_json))
      subject.remote_push
    end
  end

  describe "#local_delete" do
    it "removes a record locally" do
      expect(sf_client).not_to receive(:http_delete)
      expect(lead.class.exists?(salesforce_id: salesforce_id)).to be_truthy
      subject.local_delete
      expect(lead.class.exists?(salesforce_id: salesforce_id)).to be_falsey
    end
  end

  describe "#merge" do
    before do
      allow(sf_client).to receive(:http_patch)
      allow(sf_client).to receive(:http_get).with(kind_of(String), fields: "SystemModstamp")
        .and_return(double(body: { SystemModstamp: Time.now }.to_json))
    end

    it "pushes local attrs to merge" do
      expect(sf_client).to receive(:http_patch).with(kind_of(String), { FirstName: 'John' }.to_json)
      subject.merge(local_attributes: ['FirstName'], remote_attributes: ['LastName'])
    end

    it "pulls remote attrs to merge" do
      subject.merge(local_attributes: ['FirstName'], remote_attributes: ['LastName'])
      lead.reload
      expect(lead.LastName).to eq('Stark')
    end

    it "doesn't do any update requests if there are no local attrs to merge" do
      expect(sf_client).not_to receive(:http_patch)
      subject.merge(local_attributes: [], remote_attributes: ['LastName', 'FirstName'])
      lead.reload
      expect(lead.FirstName).to eq('Sansa')
      expect(lead.LastName).to eq('Stark')
    end

    it "raises ArgumentError when not provided local attributes or remote attributes" do
      expect { subject.merge(local_attributes: []) }.to raise_error(ArgumentError)
      expect { subject.merge(remote_attributes: []) }.to raise_error(ArgumentError)
    end
  end
end
