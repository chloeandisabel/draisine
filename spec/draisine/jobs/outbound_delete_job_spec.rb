require "spec_helper_ar"

describe Draisine::OutboundDeleteJob do
  let(:syncer) { instance_double(Draisine::Syncer) }
  let(:lead) { Lead.create_without_callbacks!(FirstName: 'John', LastName: 'Doe', salesforce_id: 'A000') }

  before do
    allow(Lead).to receive(:salesforce_syncer).and_return(syncer)
  end

  it "sends delete to syncer" do
    expect(syncer).to receive(:delete).with('A000')
    described_class.perform_now(lead)
  end

  it "is launched from after_delete callback" do
    expect(syncer).to receive(:delete).with('A000')
    lead.destroy
  end
end
