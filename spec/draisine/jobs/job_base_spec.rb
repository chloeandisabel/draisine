require "spec_helper"
require "global_id"

class Draisine::TestJob < Draisine::JobBase
  def _perform(*args)
  end
end

describe Draisine::JobBase do
  describe "error handling" do
    let(:job_class) { Draisine::TestJob }

    before do
      allow(ActiveJob::Base).to receive(:logger).and_return(ActiveSupport::TaggedLogging.new(Logger.new("/dev/null")))
      allow_any_instance_of(ActiveJob::Base).to receive(:logger).and_return(ActiveSupport::TaggedLogging.new(Logger.new("/dev/null")))
    end

    it "uses globally setup handler for errors" do
      allow(Draisine).to receive(:job_retry_attempts).and_return(0)
      allow_any_instance_of(job_class).to receive(:_perform) {|*args| fail ArgumentError, "Something went wrong" }
      exception = nil
      args = nil
      job = nil
      allow(Draisine).to receive(:job_error_handler).and_return(-> (*ex_args) { exception, job, args = ex_args })
      expect {
        job_class.perform_now("arg1", :arg2)
      }.not_to raise_error
      expect(job).to be_a(job_class)
      expect(exception).to be_an(ArgumentError)
      expect(args).to eq(["arg1", :arg2])
    end

    it "default handler re-raises errors" do
      allow(Draisine).to receive(:job_retry_attempts).and_return(0)
      allow_any_instance_of(job_class).to receive(:_perform) {|*args| fail ArgumentError, "Something went wrong" }
      expect {
        job_class.perform_now("arg1", :arg2)
      }.to raise_error(ArgumentError)
    end

    it "allows to retry job several times via re-enqueing" do
      allow(Draisine).to receive(:job_retry_attempts).and_return(1)
      retry_count = 0
      allow_any_instance_of(job_class).to receive(:_perform) {|*args| retry_count += 1; fail ArgumentError, "Something went wrong" if retry_count < 2 }
      expect {
        job_class.perform_now
      }.not_to raise_error
      expect(retry_count).to eq(2)
    end

    it "allows you to re-raise exceptions, if you must" do
      allow(Draisine).to receive(:job_retry_attempts).and_return(0)
      allow(Draisine).to receive(:job_error_handler).and_return(-> (ex, _, _) { raise ex })
      allow_any_instance_of(job_class).to receive(:_perform) {|*args| fail ArgumentError, "Horrible day" }
      expect {
        job_class.perform_now
      }.to raise_error(ArgumentError)
    end
  end
end
