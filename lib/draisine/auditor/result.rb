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
  end
end
