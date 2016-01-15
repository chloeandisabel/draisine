module Draisine
  class ConflictDetector
    attr_reader :model, :remote_model, :attributes_list
    def initialize(model, remote_model, attributes_list = model.class.salesforce_audited_attributes)
      @model = model
      @remote_model = remote_model
      @attributes_list = attributes_list
    end

    def conflict?
      conflict_type != :no_conflict
    end

    def conflict_type
      if model && remote_model
        if diff.diff_keys.empty?
          :no_conflict
        else
          :mismatching_records
        end
      elsif model
        :remote_record_missing
      elsif remote_model
        :local_record_missing
      else
        :no_conflict
      end
    end

    def diff
      return unless model && remote_model

      @diff ||= HashDiff.sf_diff(
          model.salesforce_attributes.slice(*attributes_list).compact,
          remote_model.attributes.slice(*attributes_list).compact)
    end
  end
end
