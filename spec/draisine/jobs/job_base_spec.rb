require "spec_helper"

describe Draisine::JobBase do
  describe "error handling" do
    let(:job_class) do
      Class.new(described_class) do
        def self.name
          "TestCaseJob"
        end

        def perform(*args)
        end
      end
    end

    it "uses globally setup handler for errors" do
      allow_any_instance_of(job_class).to receive(:perform) {|*args| fail ArgumentError, "Something went wrong" }
      exception = nil
      args = nil
      job = nil
      Draisine.job_error_handler = -> (ex, job_instance, arguments) { job = job_instance; exception = ex; args = arguments }
      expect {
        job_class.perform_now("arg1", :arg2)
      }.to raise_error(ArgumentError)

      expect(job).to be_a(job_class)
      expect(exception).to be_an(ArgumentError)
      expect(args).to eq(["arg1", :arg2])
    end
  end
end
