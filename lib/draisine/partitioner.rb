module Draisine
  Partition = Struct.new(:model_class, :start_date, :end_date, :updated_ids, :deleted_ids, :unpersisted_ids) do
    def initialize(model_class, *args)
      model_class = model_class.constantize if model_class.is_a?(String)
      super(model_class, *args)
    end

    def as_json(*)
      model_class, *fields = to_a
      [model_class.name, *fields].as_json
    end

    def self.from_json(fields)
      new(*fields)
    end
  end

  class Partitioner
    def self.partition(model_class, start_date, end_date, partition_size = 100, mechanism = :default)
      new(model_class, mechanism).partition(start_date, end_date, partition_size)
    end

    attr_reader :model_class, :mechanism
    def initialize(model_class, mechanism = :default)
      @model_class = model_class
      @mechanism = QueryMechanisms.fetch(mechanism).new(model_class)
    end

    def partition(start_date, end_date, partition_size = 100)
      updated_ids = get_updated_ids(start_date, end_date)
      deleted_ids = get_deleted_ids(start_date, end_date)
      unpersisted_ids = get_unpersisted_ids(start_date, end_date)

      # if anyone knows how to do this packing procedure better, please tell me
      all_ids = updated_ids.map {|id| [:updated, id] } +
                deleted_ids.map {|id| [:deleted, id] } +
                unpersisted_ids.map {|id| [:unpersisted, id] }

      if all_ids.present?
        all_ids.each_slice(partition_size).map do |slice|
          part = slice.group_by(&:first).map {|k,v| [k, v.map(&:last)] }.to_h
          Partition.new(model_class.name, start_date, end_date, part[:updated], part[:deleted], part[:unpersisted])
        end
      else
        [Partition.new(model_class.name, start_date, end_date)]
      end
    end

    protected

    def get_updated_ids(start_date, end_date)
      mechanism.get_updated_ids(start_date, end_date) |
        model_class
          .where("updated_at >= ? AND updated_at <= ?", start_date, end_date)
          .uniq.pluck(:salesforce_id).compact
    end

    def get_deleted_ids(start_date, end_date)
      mechanism.get_deleted_ids(start_date, end_date)
    end

    def get_unpersisted_ids(start_date, end_date)
      model_class
        .where("salesforce_id IS NULL OR salesforce_id = ?", '')
        .where("updated_at >= ? and updated_at <= ?", start_date, end_date)
        .pluck(:id)
    end

    def client
      Draisine.salesforce_client
    end
  end
end
