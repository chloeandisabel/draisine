require "spec_helper_ar"

describe Draisine::SoapHandler do
  describe "#update" do
    let(:example_params) { Hash.from_xml(File.read('spec/fixtures/soap_inbound_update_lead.xml')) }
    subject { described_class.new }

    it "creates a record with provided parameters if it doesn't exist" do
      subject.update(example_params)
      lead = Lead.find_by_salesforce_id('00Q7A000001CYIAUA4')
      expect(lead).to be_present
      expect(lead.FirstName).to eq('Mark')
      expect(lead.LastName).to eq('Abramov')
    end

    it "updates record with message parameters if it already exists" do
      lead = Lead.create_without_callbacks!(FirstName: 'John', LastName: 'Doe', salesforce_id: '00Q7A000001CYIAUA4')
      subject.update(example_params)
      lead.reload
      expect(lead.FirstName).to eq('Mark')
      expect(lead.LastName).to eq('Abramov')
    end

    it "raises error when given non-proper hash" do
      expect {
        subject.update({})
      }.to raise_error(ArgumentError)
    end
  end

  describe "#delete" do
    let(:example_params) { Hash.from_xml(File.read('spec/fixtures/soap_inbound_delete_lead.xml')) }
    subject { described_class.new }

    it "deletes a record with provided parameters" do
      Lead.create_without_callbacks!(salesforce_id: '00Q7A000001DUEsUAO')
      subject.delete(example_params)
      expect(Lead.exists?(salesforce_id: '00Q7A000001DUEsUAO')).to be_falsey
    end

    it "doesn't raise error if it couldn't find a record" do
      expect { subject.delete(example_params) }.not_to raise_error
    end
  end
end