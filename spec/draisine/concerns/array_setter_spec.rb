require "spec_helper"

describe Draisine::Concerns::ArraySetter do
  let(:described_class) do
    Class.new do
      include Draisine::Concerns::ArraySetter
      attr_accessor :items
      salesforce_array_setter :items
    end
  end

  subject { described_class.new }

  describe ".salesforce_array_setter" do
    it "leaves arrays as is" do
      subject.items = [1, 2, 3]
      expect(subject.items).to eq([1, 2, 3])
    end

    it "splits strings on semicolons" do
      subject.items = "1;2;3;4"
      expect(subject.items).to eq(['1', '2', '3', '4'])
    end

    it "turns nils into empty arrays" do
      subject.items = nil
      expect(subject.items).to eq([])
    end
  end
end
