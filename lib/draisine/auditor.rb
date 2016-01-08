module Draisine
  class Auditor
    Discrepancy = Struct.new(:type, :salesforce_id, :local_attrs, :remote_attrs, :diff_keys)

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

      def discrepancy(type, salesforce_id, local_attrs = nil, remote_attrs = nil, diff = nil)
        discrepancies << Discrepancy.new(type, salesforce_id, local_attrs, remote_attrs, diff)
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
        result.discrepancy(:local_record_without_salesforce_id,
          nil,
          record.attributes)
      end
    end

    def check_deletes
      deleted_ids = client.get_deleted(
        salesforce_object_name, start_date, end_date).
        fetch('deletedRecords').
        map {|r| r['id']}
      ghost_models = model_class.where(salesforce_id: deleted_ids).all
      ghost_models.each do |ghost_model|
        result.discrepancy(:remote_delete_kept_locally,
          ghost_model.salesforce_id,
          ghost_model.attributes)
      end
    end

    def check_modifications
      updated_ids = client.get_updated(
        salesforce_object_name, start_date, end_date).fetch('ids')
      updated_ids += model_class.where("updated_at >= ? AND updated_at <= ?", start_date, end_date)
        .pluck(:salesforce_id).compact
      return unless updated_ids.any?
      local_records = model_class.where(salesforce_id: updated_ids).map(&:attributes)
      remote_records = client.fetch_multiple(salesforce_object_name, updated_ids).map(&:attributes)
      local_records_map = build_map(local_records, 'salesforce_id')
      remote_records_map = build_map(remote_records, 'Id')

      missing_ids = updated_ids - local_records_map.keys
      missing_ids.each do |id|
        result.discrepancy(:remote_record_missing_locally,
          id, nil, remote_records_map.fetch(id))
      end

      attr_list = model_class.salesforce_audited_attributes
      local_records_map.each do |id, local_record|
        remote_record = remote_records_map.fetch(id)
        diff = hash_diff(local_record, remote_record, attr_list)
        unless diff.empty?
          result.discrepancy(:mismatching_records,
            id, local_record, remote_record, diff)
        end
      end
    end

    def client
      Draisine.salesforce_client
    end

    protected

    def build_map(list_of_hashes, key)
      list_of_hashes.each_with_object({}) do |item, rs|
        rs[item.fetch(key)] = item
      end
    end

    def hash_diff(hash1, hash2, keys)
      keys.map(&:to_s).select {|k| hash1[k] != hash2[k] }
    end
  end
end
