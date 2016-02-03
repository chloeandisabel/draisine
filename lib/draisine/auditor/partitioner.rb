module Draisine
  class Auditor
    AuditPartition = Struct.new(:model_class, :start_date, :end_date, :updated_ids, :deleted_ids, :unpersisted_ids)

    class Partitioner
      def self.partition(*args)
        new.partition(*args)
      end

      def partition(model_class, start_date, end_date, partition_size = 100)
        updated_ids = get_updated_ids(model_class, start_date, end_date)
        deleted_ids = get_deleted_ids(model_class, start_date, end_date)
        unpersisted_ids = get_unpersisted_ids(model_class, start_date, end_date)

        # if anyone knows how to do this packing procedure better, please tell me
        all_ids = updated_ids.map {|id| [:updated, id] } +
                  deleted_ids.map {|id| [:deleted, id] } +
                  unpersisted_ids.map {|id| [:unpersisted, id] }

        if all_ids.present?
          all_ids.each_slice(partition_size).map do |slice|
            part = slice.group_by(&:first).map {|k,v| [k, v.map(&:last)] }.to_h
            AuditPartition.new(model_class, start_date, end_date, part[:updated], part[:deleted], part[:unpersisted])
          end
        else
          [AuditPartition.new(model_class, start_date, end_date)]
        end
      end

      protected

      def get_updated_ids(model_class, start_date, end_date)
        updated_ids = client.get_updated_ids(model_class.salesforce_object_name, start_date, end_date)
        updated_ids += model_class.where("updated_at >= ? AND updated_at <= ?", start_date, end_date)
          .pluck(:salesforce_id).compact
        updated_ids.uniq
      end

      def get_deleted_ids(model_class, start_date, end_date)
        client.get_deleted_ids(model_class.salesforce_object_name, start_date, end_date)
      end

      def get_unpersisted_ids(model_class, start_date, end_date)
        model_class.where("salesforce_id IS NULL OR salesforce_id = ?", '')
                   .where("updated_at >= ? and updated_at <= ?", start_date, end_date)
                   .pluck(:id)
      end

      def client
        Draisine.salesforce_client
      end
    end
  end
end
