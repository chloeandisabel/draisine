module Draisine
  class Poller
    Result = Struct.new(:created_count, :updated_count, :deleted_count)

    class <<self
      def run(model_class:, mechanism: :default, start_date:, end_date: Time.current, **run_args)
        partitions = partition(
          model_class: model_class,
          mechanism: mechanism,
          start_date: start_date,
          end_date: end_date,
          partition_size: 10**12)
        run_partition(partitions.first, **run_args)
      end
      alias_method :poll, :run

      def partition(model_class:, mechanism: :default, start_date:, end_date: Time.current, partition_size: 100)
        Partitioner.partition(
          model_class: model_class,
          mechanism: mechanism,
          start_date: start_date,
          end_date: end_date,
          partition_size: partition_size)
      end

      def run_partition(partition, **run_args)
        new(partition).run(**run_args)
      end
      alias_method :poll_partition, :run_partition
    end


    attr_reader :partition, :model_class, :start_date, :end_date
    def initialize(partition)
      @partition = partition
      @model_class = partition.model_class
      @start_date = partition.start_date
      @end_date = partition.end_date
    end

    def run(import_created: true, import_updated: false, import_deleted: true)
      created_count = updated_count = deleted_count = 0
      if import_created || import_updated
        created_count, updated_count = import_changes(import_created, import_updated)
      end

      deleted_count = import_deletes if import_deleted

      Result.new(
        created_count,
        updated_count,
        deleted_count)
    end
    alias_method :poll, :run

    protected

    def import_changes(import_created, import_updated)
      updated_ids = partition.updated_ids
      return [0, 0] unless updated_ids.present?

      created_count = updated_count = 0
      changed_objects = client.fetch_multiple(salesforce_object_name, updated_ids)

      existing_models = model_class
        .where(salesforce_id: updated_ids)
        .each_with_object({}) { |model, rs| rs[model.salesforce_id] = model }

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

    def import_deletes
      deleted_ids = partition.deleted_ids
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
