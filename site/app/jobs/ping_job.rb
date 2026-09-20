# Infrastructure smoke job: proves the Active Job → Solid Queue path.
# Broadcasts on PingChannel's stream so a cable client can watch it land.
class PingJob < ApplicationJob
  queue_as :default

  def perform(note = "pong")
    ActionCable.server.broadcast("ping", { note: note, at: Time.current.iso8601 })
  end
end
