require "test_helper"

class PingChannelTest < ActionCable::Channel::TestCase
  test "subscribes and streams ping" do
    subscribe

    assert subscription.confirmed?
    assert_has_stream "ping"
  end

  test "broadcasts on the ping stream reach subscribers" do
    subscribe

    assert_broadcast_on("ping", { note: "pong" }) do
      ActionCable.server.broadcast("ping", { note: "pong" })
    end
  end
end
