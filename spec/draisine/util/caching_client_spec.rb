require "spec_helper"

describe Draisine::CachingClient do
  include_context "Salesforce stubs"
  let(:client) { double(:client, find: nil, fetch_multiple: []) }
  subject { described_class.new(client) }

  it "caches #find requests" do
    model = MaterializedModelInstance.new("Id" => "A000")
    expect(client).to receive(:find).once.and_return(model)
    subject.find("Lead", "A000")
    response = subject.find("Lead", "A000")
    expect(response).to eq(model)
  end

  it "caches #fetch_multiple requests" do
    models = [
      MaterializedModelInstance.new("Id" => "A000"),
      MaterializedModelInstance.new("Id" => "A001")
    ]
    expect(client).to receive(:fetch_multiple).once.and_return(models)
    expect(subject.fetch_multiple("Lead", ["A000", "A001"])).to eq(models)
    expect(subject.fetch_multiple("Lead", ["A000", "A001"])).to eq(models)
  end

  it "allows prefetching ids beforehand" do
    models = [
      MaterializedModelInstance.new("Id" => "A000"),
      MaterializedModelInstance.new("Id" => "A001")
    ]
    allow(client).to receive(:fetch_multiple).once.and_return(models)
    subject.prefetch("Lead", ["A000", "A001"])
    model = subject.find("Lead", "A000")
    expect(model).to eq(models[0])
  end
end
