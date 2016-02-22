module Draisine
  class Poller
    Result = Struct.new(:salesforce_count, :db_count, :created_count, :updated_count, :deleted_count)

    attr_reader :model_class, :mechanism

    def initialize(model_class, mechanism = :default)
      @model_class = model_class
      @mechanism = QueryMechanisms.fetch(mechanism).new(model_class)
    end

    def poll(start_date, end_date = Time.now, import_created: true, import_updated: false, import_deleted: true)
      created_count = updated_count = deleted_count = 0
      if import_created || import_updated
        created_count, updated_count = import_changes(start_date, end_date, import_created, import_updated)
      end

      if import_deleted
        deleted_count = import_deletes(start_date, end_date)
      end

      Result.new(
        client.count(salesforce_object_name),
        model_class.count,
        created_count,
        updated_count,
        deleted_count)
    end

    protected

    def import_changes(start_date, end_date, import_created, import_updated)
      created_count = updated_count = 0
      changed_ids = mechanism.get_updated_ids(start_date, end_date)
      changed_objects = client.fetch_multiple(salesforce_object_name, changed_ids)
      existing_models = model_class.where(salesforce_id: changed_ids)
        .each_with_object({}) {|model, rs| rs[model.salesforce_id] = model }
      changed_objects.each do |object|
        id = object.attributes.fetch('Id')
        model = existing_models[id]
        is_new = !model
        attrs = object.attributes
        if is_new && import_created
          model_class.import_or_update_with_attrs(id, attrs)
          created_count += 1
        elsif !is_new && import_updated
          if model.salesforce_update_without_sync(attrs, true)
            updated_count += 1
          end
        end
      end

      [created_count, updated_count]
    end

    def import_deletes(start_date, end_date)
      deleted_ids = mechanism.get_deleted_ids(start_date, end_date)
      return 0 unless deleted_ids.present?
      model_class.where(salesforce_id: deleted_ids).delete_all
    end

    def client
      Draisine.salesforce_client
    end

    def salesforce_object_name
      model_class.salesforce_object_name
    end
  end
end
