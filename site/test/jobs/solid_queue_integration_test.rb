require "test_helper"

# Proves the real Solid Queue path (adapter → queue database), not just the
# :test adapter: enqueue through the solid_queue adapter and assert the job
# row lands in solid_queue_jobs. Execution is exercised by bin/jobs in dev.
class SolidQueueIntegrationTest < ActiveSupport::TestCase
  test "perform_later through the solid_queue adapter writes a job row" do
    original = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :solid_queue

    assert_difference -> { SolidQueue::Job.count }, +1 do
      PingJob.perform_later("solid queue integration")
    end

    job = SolidQueue::Job.order(:id).last
    assert_equal "PingJob", job.class_name
    assert_equal "default", job.queue_name
  ensure
    ActiveJob::Base.queue_adapter = original
    SolidQueue::Job.destroy_all
  end
end
