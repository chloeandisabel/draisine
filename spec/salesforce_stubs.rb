shared_context "Salesforce stubs" do
  Collection = Struct.new(:items, :next_page) do
    include Enumerable
    def each(&block)
      items.each(&block)
    end

    def next_page?
      !!next_page
    end
  end

  MaterializedModel = Struct.new(:type_map) do
    def field_list
      type_map.keys.join(',')
    end
  end

  MaterializedModelInstance = Struct.new(:attributes)

  let(:sf_client) { double(:client, version: 'v29.0') }
  let(:lead_type_map) {
    {
      "Id" => {:type => "string"},
      "FirstName" => {:type => "string"},
      "LastName" => {:type => "string"}
    }
  }

  def salesforce_stub_out_leads!
    leads = []
    allow(Draisine).to receive(:salesforce_client).and_return(sf_client)
    allow(Lead).to receive(:salesforce_syncer).and_return(Draisine::Syncer.new(Lead, sf_client))
    allow(Lead).to receive(:salesforce_synced_attributes).and_return(['FirstName', 'LastName'])
    allow(sf_client).to receive(:materialize) {
      MaterializedModel.new(lead_type_map)
    }
    allow(sf_client).to receive(:query) {
      Collection.new(leads.map {|attrs| MaterializedModelInstance.new(attrs) })
    }
  end
end
