require "spec_helper_ar"

describe Draisine::InboundUpdateJob do
  it "updates the model with the corresponding salesforce id with given attrs" do
    lead = Lead.create_without_callbacks!(salesforce_id: 'A000', FirstName: 'Mark')
    described_class.perform_now('Lead', { 'Id' => 'A000', 'FirstName' => 'John' })
    lead.reload
    expect(lead.FirstName).to eq('John')
  end

  it "creates a model if necessary" do
    expect {
      described_class.perform_now('Lead', { 'Id' => 'A000', 'FirstName' => 'John' })
    }.to change { Lead.count }.by(1)
    lead = Lead.find_by_salesforce_id('A000')
    expect(lead.FirstName).to eq('John')
  end
end
