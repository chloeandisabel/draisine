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

    it "uses text columns for strings without specified length" do
      mapper = described_class.new({
        "Name" => {:label => "Full name", :type => "string", :updateable? => true},
        "SecondName" => {:label => "Second name", :type => "string", :updateable? => true, length: 0}
      })
      coldefs = mapper.active_record_column_defs
      expect(coldefs.map(&:column_type)).to eq [:text, :text]
    end

    it "uses string columns for strings < 40 chars and text columns for strings > 40 chars" do
      mapper = described_class.new({
        "Short" => {:label => "Full name", :type => "string", :updateable? => true, length: Draisine::TypeMapper::MAX_ALLOWED_STRING_TYPE_LENGTH},
        "Long" => {:label => "Second name", :type => "string", :updateable? => true, length: Draisine::TypeMapper::MAX_ALLOWED_STRING_TYPE_LENGTH + 1}
      })
      coldefs = mapper.active_record_column_defs
      expect(coldefs.map(&:column_type)).to eq [:string, :text]
      expect(coldefs.map {|coldef| coldef.options[:limit]}).to eq [Draisine::TypeMapper::MAX_ALLOWED_STRING_TYPE_LENGTH, nil]
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

    it "uses text for comboboxes" do
      mapper = described_class.new({
        "Value" => {:label => "Some custom value", :type => "combobox", :updateable? => true}
      })
      expect(mapper.active_record_column_defs.first.column_type).to eq :text
    end

    it "uses decimals for currencies" do
      mapper = described_class.new({
        "CurrencyValue" => {:label => "Some custom currency value", :type => "currency", :updateable? => true}
      })
      expect(mapper.active_record_column_defs.first.column_type).to eq :decimal
    end

    it "uses decimals for percents" do
      mapper = described_class.new({
        "PercentValue" => {:label => "Some custom percent value", :type => "percent", :updateable? => true}
      })
      expect(mapper.active_record_column_defs.first.column_type).to eq :decimal
    end

    it "doesn't not create a column for Id" do
      mapper = described_class.new({
        "Id" => {:label => "Lead", :type => "id", :updateable? => false}
      })
      expect(mapper.active_record_column_defs).to eq []
    end

    it "uses integers for doubles with scale=0" do
      mapper = described_class.new({
        "Field_ID__c" => {:label => "ID", :type => "double", :updateable? => true, :precision => 18, :scale => 0}
      })
      expect(mapper.active_record_column_defs.first.column_type).to eq :integer
    end

    it "uses floats for doubles with scale > 0" do
      mapper = described_class.new({
        "Field__c" => {:label => "Value", :type => "double", :updateable? => true, :precision => 18, :scale => 2}
      })
      expect(mapper.active_record_column_defs.first.column_type).to eq :float
    end

    it "ignores encrypted strings for now"
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
