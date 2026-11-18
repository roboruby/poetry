# frozen_string_literal: true

# installed by the poetry `screen-chat-ruby-llm` recipe - this file is
# yours. `include ChatTurn` in Chat (beside acts_as_chat), and give
# chats a responding_since datetime column:
#
#   bin/rails g migration AddRespondingSinceToChats responding_since:datetime
#
# The server's record of a turn: a reply was accepted and has not ended.
# The composer draws Send or Stop from it, so a reload in the middle of a
# reply still shows Stop, and a message sent while one runs can be refused.
module ChatTurn
  extend ActiveSupport::Concern

  # A turn whose process died stops counting as running after this long,
  # so the composer cannot stay on Stop for ever.
  TURN_CEILING = 10.minutes

  # Whether a reply is being written.
  def responding?
    responding_since.present? && responding_since > TURN_CEILING.ago
  end

  # A turn is accepted. A stop left over from the turn before would stop
  # this one at its first chunk, so it is cleared here.
  def begin_turn!
    update_columns(responding_since: Time.current, cancelled: false)
  end

  def end_turn!
    update_columns(responding_since: nil)
  end

  # What the composer's action slot draws: Send (:idle), Stop (:running),
  # or Stop busy (:stopping) once Stop was pressed and the reply has not
  # ended yet. Read fresh: the job and the Stop request are other processes.
  def composer_status
    return :idle unless responding?

    self.class.uncached { self.class.where(id: id).pick(:cancelled) } ? :stopping : :running
  end
end
