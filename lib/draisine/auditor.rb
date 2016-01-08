module Draisine
  class Auditor
    Discrepancy = Struct.new(:type, :salesforce_type, :salesforce_id, :local_type, :local_id, :local_attributes, :remote_attributes, :diff_keys)

    class Result
      attr_reader :discrepancies, :status, :error
      def initialize
        @discrepancies = []
        @status = :running
        @error = nil
      end

      def calculate_result!
        if discrepancies.any?
          @status = :failure
        else
          @status = :success
        end
        self
      end

      def error!(ex)
        @error = ex
        @status = :failure
        self
      end

      def success?
        @status == :success
      end

      def failure?
        @status == :failure
      end

      def running?
        @status == :running
      end

      def discrepancy(type:, salesforce_type:, salesforce_id:,
          local_type: nil, local_id: nil, local_attributes: nil, remote_attributes: nil, diff_keys: nil)

        discrepancies << Discrepancy.new(type, salesforce_type, salesforce_id,
          local_type, local_id, local_attributes, remote_attributes, diff_keys)
      end
    end

    def self.run(model_class, start_date = Time.now.beginning_of_day, end_date = Time.now)
      new(model_class).run(start_date, end_date)
    end

    attr_reader :model_class, :salesforce_object_name,
                :start_date, :end_date, :result
    def initialize(model_class)
      @model_class = model_class
      @salesforce_object_name = model_class.salesforce_object_name
    end

    def run(start_date = Time.now.beginning_of_day, end_date = Time.now.end_of_day)
      @result = Result.new
      @start_date = start_date
      @end_date = end_date

      check_unpersisted_records
      check_deletes
      check_modifications

      result.calculate_result!
    rescue => e
      result.error!(e)
      raise
    end

    def check_unpersisted_records
      bad_records = model_class.where("salesforce_id IS NULL OR salesforce_id = ?", '')
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
      deleted_ids = client.get_deleted(
        salesforce_object_name, start_date, end_date).
        fetch('deletedRecords').
        map {|r| r['id']}
      ghost_models = model_class.where(salesforce_id: deleted_ids).all
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
      updated_ids = client.get_updated(
        salesforce_object_name, start_date, end_date).fetch('ids')
      updated_ids += model_class.where("updated_at >= ? AND updated_at <= ?", start_date, end_date)
        .pluck(:salesforce_id).compact

      return unless updated_ids.any?

      local_records = model_class.where(salesforce_id: updated_ids).to_a
      remote_records = client.fetch_multiple(salesforce_object_name, updated_ids).map(&:attributes)

      local_records_map = build_map(local_records) {|record| record.salesforce_id }
      remote_records_map = build_map(remote_records) {|record| record.fetch('Id') }

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
        remote_attributes = remote_records_map[salesforce_id]
        next unless remote_attributes
        local_attributes = local_record.salesforce_attributes
        diff = hash_diff(local_attributes, remote_attributes, attr_list)
        unless diff.empty?
          result.discrepancy(
            type: :mismatching_records,
            salesforce_type: salesforce_object_name,
            salesforce_id: salesforce_id,
            local_id: local_record.id,
            local_type: local_record.class.name,
            local_attributes: local_attributes,
            remote_attributes: remote_attributes,
            diff_keys: diff)
        end
      end
    end

    def client
      Draisine.salesforce_client
    end

    protected

    def build_map(list_of_hashes, &key_block)
      list_of_hashes.each_with_object({}) do |item, rs|
        rs[key_block.call(item)] = item
      end
    end

    def hash_diff(hash1, hash2, keys)
      keys.map(&:to_s).select {|k| hash1[k] != hash2[k] }
    end
  end
end
