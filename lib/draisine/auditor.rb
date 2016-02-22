require "draisine/auditor/result"

module Draisine
  class Auditor
    def self.run(model_class, start_date = Time.now.beginning_of_day, end_date = Time.now)
      # TODO: instead of using one huge partition, combine multiple results into one
      partitions = partition(model_class, start_date, end_date, 10**12)
      run_partition(partitions.first)
    end

    def self.run_partition(partition)
      new(partition).run
    end

    def self.partition(model_class, start_date, end_date, partition_size = 100)
      Partitioner.partition(model_class, start_date, end_date, partition_size)
    end

    attr_reader :partition, :model_class, :start_date, :end_date, :result
    def initialize(partition)
      @partition = partition
      @model_class = partition.model_class
      @start_date = partition.start_date
      @end_date = partition.end_date
    end

    def run
      @result = Result.new

      check_unpersisted_records
      check_deletes
      check_modifications

      result.calculate_result!
    rescue => e
      result.error!(e)
      raise
    end

    def check_unpersisted_records
      return unless partition.unpersisted_ids.present?

      bad_records = model_class.where(id: partition.unpersisted_ids)
      bad_records.each do |record|
        result.discrepancy(
          type: :local_record_without_salesforce_id,
          salesforce_type: salesforce_object_name,
          salesforce_id: nil,
          local_id: record.id,
          local_type: record.class.name,
          local_attributes: record.attributes)
      end
    end

    def check_deletes
      return unless partition.deleted_ids.present?

      ghost_models = model_class.where(salesforce_id: partition.deleted_ids).all
      ghost_models.each do |ghost_model|
        result.discrepancy(
          type: :remote_delete_kept_locally,
          salesforce_type: salesforce_object_name,
          salesforce_id: ghost_model.salesforce_id,
          local_id: ghost_model.id,
          local_type: ghost_model.class.name,
          local_attributes: ghost_model.attributes)
      end
    end

    def check_modifications
      updated_ids = partition.updated_ids
      return unless updated_ids.present?

      local_records = model_class.where(salesforce_id: updated_ids).to_a
      remote_records = client.fetch_multiple(salesforce_object_name, updated_ids)

      local_records_map = build_map(local_records) {|record| record.salesforce_id }
      remote_records_map = build_map(remote_records) {|record| record.Id }

      missing_ids = updated_ids - local_records_map.keys
      missing_ids.each do |id|
        result.discrepancy(
          type: :remote_record_missing_locally,
          salesforce_type: salesforce_object_name,
          salesforce_id: id,
          remote_attributes: remote_records_map.fetch(id))
      end

      attr_list = model_class.salesforce_audited_attributes
      local_records_map.each do |salesforce_id, local_record|
        remote_record = remote_records_map[salesforce_id]
        next unless remote_record
        conflict_detector = ConflictDetector.new(local_record, remote_record, attr_list)

        if conflict_detector.conflict?
          result.discrepancy(
            type: :mismatching_records,
            salesforce_type: salesforce_object_name,
            salesforce_id: salesforce_id,
            local_id: local_record.id,
            local_type: local_record.class.name,
            local_attributes: local_record.salesforce_attributes,
            remote_attributes: remote_record.attributes,
            diff_keys: conflict_detector.diff.diff_keys)
        end
      end
    end

    protected

    def client
      Draisine.salesforce_client
    end

    def build_map(list_of_hashes, &key_block)
      list_of_hashes.each_with_object({}) do |item, rs|
        rs[key_block.call(item)] = item
      end
    end

    def salesforce_object_name
      model_class.salesforce_object_name
    end
  end
end
