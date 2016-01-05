require 'rails/generators/active_record'

module Draisine
  class IntegrationGenerator < Rails::Generators::Base
    self.source_root(File.expand_path('../templates/', __FILE__))

    desc <<-DESC
    Uses materialized models from salesforce.
    Generates a migration creating an integration table for a salesforce model and
    an active_record model under app/models/salesforce/
    DESC

    argument :model, type: :string,
                     banner: "ModelName",
                     desc: "Model name for active record (e.g. Lead)",
                     required: true
    argument :salesforce_object_name, type: :string,
                     banner: "SalesforceObjectName",
                     desc: "Salesforce object name (inferred from ModelName by default)",
                     required: false
    def create_salesforce_integrations
      @model_name = model.classify.singularize
      @model_file = "app/models/#{model.underscore.singularize}.rb"
      @table_name = model.underscore.gsub("/", "_").pluralize
      @migration_title = "CreateSalesforce#{model.classify.gsub('::', '').pluralize}"
      @migration_file = existing_migration_name(@migration_title) ||
                        "db/migrate/#{migration_number}_#{@migration_title.underscore}.rb"

      @salesforce_object_name = salesforce_object_name || model.classify.demodulize
      @materialized_model = Draisine.salesforce_client.materialize(@salesforce_object_name)
      @mapper = Draisine::TypeMapper.new(@materialized_model.type_map)
      @ar_col_defs = @mapper.active_record_column_defs
      @columns = @mapper.active_record_column_defs.map(&:column_name)
      @serialized_columns = @mapper.serialized_columns
      @array_columns = @mapper.array_columns
      @non_audited_columns = @mapper.columns - @mapper.updateable_columns

      template "migration.rb", @migration_file
      template "model.rb", @model_file
    end

    protected

    def migration_number
      Time.now.utc.strftime("%Y%m%d%H%M%S")
    end

    # This is needed for rails destroy to work, since every time we generate a new name for our migration
    def existing_migration_name(migration_title)
      Dir.glob("#{Rails.root}/db/migrate/[0-9]*_#{migration_title.underscore}.rb").first
    end
  end
end
