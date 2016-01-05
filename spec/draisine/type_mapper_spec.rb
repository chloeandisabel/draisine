require "spec_helper"

describe Draisine::TypeMapper do
  describe "#active_record_column_defs" do
    it "returns a list of structs with appropriate colnames and types" do
      mapper = described_class.new({
        "Name" => {:label => "Full name", :type => "string", :updateable? => true}
      })
      coldefs = mapper.active_record_column_defs
      expect(coldefs).to be_an(Array)
      expect(coldefs.count).to eq 1
      coldef = coldefs.first
      expect(coldef.column_name).to eq 'Name'
      expect(coldef.column_type).to eq :text
    end

    it "uses binary columns for picklists and multipicklists" do
      mapper = described_class.new({
        "PhoneType__c" => {
          :type => "picklist",
          :label => "PhoneType",
          :picklist_values => [],
          :updateable? => true
        },
        "ContactRole__c" => {
          :type => "multipicklist",
          :label => "Contact Role",
          :picklist_values => [],
          :updateable? => true
        }
      })
      coldefs = mapper.active_record_column_defs
      expect(coldefs.map(&:column_type)).to eq [:binary, :binary]
    end

    it "uses string columns for references" do
      mapper = described_class.new({
        "LastModifiedBy" => {:label => "Last Modified By ID", :type => "reference", :updateable? => true}
      })
      expect(mapper.active_record_column_defs.first.column_type).to eq :string
    end

    it "doesn't not create a column for Id" do
      mapper = described_class.new({
        "Id" => {:label => "Lead", :type => "id", :updateable? => false}
      })
      expect(mapper.active_record_column_defs).to eq []
    end

    it "ignores currency and encrypted strings for now"
  end

  describe "#serialized_columns" do
    it "returns a list of serializable columns (picklists and multipicklists)" do
      mapper = described_class.new({
        "PhoneType__c" => {
          :type => "picklist",
          :label => "PhoneType",
          :picklist_values => [],
          :updateable? => true
        },
        "ContactRole__c" => {
          :type => "multipicklist",
          :label => "Contact Role",
          :picklist_values => [],
          :updateable? => true
        },
        "Name" => {
          :label => "Full name",
          :type => "string",
          :updateable? => true
        },
        "Field" => {
          :label => "Field",
          :type => "anyType",
          :updateable? => true
        },
      })
      expect(mapper.serialized_columns).to match ['PhoneType__c', 'ContactRole__c', 'Field']
    end
  end

  describe "#columns" do
    it "returns a plain list of columns" do
      mapper = described_class.new({
        "Name" => {:label => "Full name", :type => "string", :updateable? => true}
      })
      expect(mapper.columns).to eq ["Name"]
    end

    it "excludes Id" do
      mapper = described_class.new({
        "Id" => {:label => "Lead", :type => "id", :updateable? => true}
      })
      expect(mapper.columns).to eq []
    end
  end

  describe "#updateable_columns" do
    it "returns a list of columns with :updateable? flag set" do
      mapper = described_class.new({
        "Name" => {:label => "Full name", :type => "string", :updateable? => true},
        "Lead Number" => {:label => "Id", :type => "string", :updateable? => false}
      })
      expect(mapper.updateable_columns).to eq ["Name"]
    end
  end

  describe "#array_columns" do
    it "returns a list of columns with array-like values" do
      mapper = described_class.new({
        "Name" => {:label => "Full name", :type => "string", :updateable? => true},
        "Values" => {:label => "Values from a list", :type => "multipicklist", :updateable? => true},
      })
      expect(mapper.array_columns).to eq ["Values"]
    end
  end
end
