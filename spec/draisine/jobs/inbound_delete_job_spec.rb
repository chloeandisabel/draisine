require "spec_helper_ar"

describe Draisine::InboundDeleteJob do
  it "deletes the model with matching salesforce id" do
    Lead.create_without_callbacks!(salesforce_id: 'A000')
    described_class.perform_now(Lead, 'A000')
    expect(Lead.exists?(salesforce_id: 'A000')).to be_falsey
  end

  it "handles non-existing records fine" do
    expect {
      described_class.perform_now(Lead, 'A000')
    }.not_to raise_error
  end
end
