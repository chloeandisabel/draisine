require "spec_helper_ar"

describe Draisine::OutboundCreateJob do
  let(:syncer) { instance_double(Draisine::Syncer).as_null_object }
  let(:lead) { Lead.create_without_callbacks!(FirstName: 'John') }

  before do
    allow(Lead).to receive(:salesforce_syncer) { syncer }
  end

  it "sends create with attributes" do
    expect(syncer).to receive(:create).with(hash_including({
      'FirstName' => 'John'
    })).and_return({'id' => 'A000', 'success' => true})
    described_class.perform_now(lead)
  end

  it "updates instance salesforce_id afterwards" do
    expect(syncer).to receive(:create).with(hash_including({
      'FirstName' => 'John'
    })).and_return({'id' => 'A000', 'success' => true})
    described_class.perform_now(lead)
    expect(lead.reload.salesforce_id).to eq('A000')
  end

  it "works as inlined job from callback" do
    allow(syncer).to receive(:create).with(hash_including({
      'FirstName' => 'Jack'
    })).and_return({'id' => 'A000', 'success' => true})
    lead = Lead.create!(FirstName: 'Jack')
    expect(lead.reload.salesforce_id).to eq('A000')
  end
end
