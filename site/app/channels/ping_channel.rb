# Infrastructure smoke channel: proves the Action Cable stack (subscription,
# streaming, broadcast). Turbo::StreamsChannel rides the same rails.
class PingChannel < ApplicationCable::Channel
  def subscribed
    stream_from "ping"
  end
end
