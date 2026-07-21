require "test_helper"

class PingJobTest < ActiveJob::TestCase
  include ActionCable::TestHelper

  test "enqueues on the default queue" do
    assert_enqueued_with(job: PingJob, args: [ "hi" ], queue: "default") do
      PingJob.perform_later("hi")
    end
  end

  test "performing broadcasts on the ping stream" do
    assert_broadcasts("ping", 1) do
      PingJob.perform_now("performed")
    end

    message = JSON.parse(ActionCable.server.pubsub.broadcasts("ping").last)
    assert_equal "performed", message["note"]
  end
end
