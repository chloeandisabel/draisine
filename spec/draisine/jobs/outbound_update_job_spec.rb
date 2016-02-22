require "spec_helper_ar"

describe Draisine::OutboundUpdateJob do
  let(:syncer) { instance_double(Draisine::Syncer) }
  let(:lead) { Lead.create_without_callbacks!(FirstName: 'John', LastName: 'Doe', salesforce_id: 'A000') }

  before do
    allow(Lead).to receive(:salesforce_syncer).and_return(syncer)
    allow(syncer).to receive(:get_system_modstamp).and_return(Time.current)
  end

  it "sends changed fields, including nulls" do
    lead.FirstName = nil
    expect(syncer).to receive(:update).with('A000', {
      'FirstName' => nil
    })
    described_class.perform_now(lead, {'FirstName' => nil})
  end

  it "is launched from after_update callback" do
    lead.FirstName = nil
    expect(syncer).to receive(:update).with('A000', {
      'FirstName' => nil
    })
    lead.save!
  end
end
