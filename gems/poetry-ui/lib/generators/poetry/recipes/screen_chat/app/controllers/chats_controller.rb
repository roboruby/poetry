# frozen_string_literal: true

# installed by the poetry `screen-chat` recipe - this file is yours: edit
# freely. Wire the routes yourself (so your routes.rb is never touched by
# an installer):
#
#   resource :chat, only: %i[show create] do
#     post :stop
#   end
#
# The view renders the chat block (installed alongside at
# app/views/blocks/_chat.html.erb). This controller is the server half,
# with a stand-in where your model goes: a message answers with the
# person's row and a reply, appended to the transcript by Turbo Streams.
# Nothing is stored and the reply is written at once, so the composer
# never leaves Send.
#
# With a model the turn takes time, and the composer shows it:
#
#   1. create saves the message, records that a reply is running, starts
#      the reply in a job, and answers with the person's row and the
#      action slot drawn as Stop:
#        turbo_stream.replace("chat-action",
#                             helpers.poetry_composer_action(id: "chat", status: :running))
#   2. The job appends the reply's row, replaces it as the text grows,
#      and draws the slot as :idle when the reply ends.
#   3. The view passes status: from that record, so a reload mid-reply
#      shows Stop, and create refuses a message while one runs
#      (head :conflict): the field keeps what was typed.
#   4. stop asks the reply to stop.
#
# The Composer page of the Poetry docs walks through each step.
class ChatsController < ApplicationController
  def show; end

  # POST: a message from the composer. A blank one is refused, and the
  # field keeps what was typed whenever the answer is not a success.
  def create
    text = params[:message].to_s.strip
    return head(422) if text.empty?

    render turbo_stream: [
      turbo_stream.append("chat-thread-messages", partial: "chats/message",
                                                  locals: { id: row_id, role: :user, text: text }),
      turbo_stream.append("chat-thread-messages", partial: "chats/message",
                                                  locals: { id: row_id, role: :assistant, text: reply_to(text) })
    ]
  end

  # POST: Stop. Nothing runs here to stop, so the slot is drawn as Send.
  def stop
    render turbo_stream: turbo_stream.replace(
      "chat-action", helpers.poetry_composer_action(id: "chat", status: :idle)
    )
  end

  private

  # The stand-in for your model: the reply to one message.
  def reply_to(_text)
    "This reply is a stand-in. Your model's answer goes in ChatsController#reply_to."
  end

  def row_id = "message-#{SecureRandom.hex(4)}"
end
