module Draisine
  class ConflictDetector
    attr_reader :model, :remote_model, :attributes_list
    def initialize(model, remote_model, attributes_list)
      @model = model
      @remote_model = remote_model
      @attributes_list = attributes_list
    end

    def conflict?
      conflict_type != :no_conflict
    end

    def conflict_type
      if model && remote_model
        if diff.removed.empty? && diff.changed.empty? && diff.added.empty?
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

      @diff ||= HashDiff.diff(
          model.attributes.slice(*attributes_list),
          remote_model.attributes.slice(*attributes_list))
    end
  end
end
