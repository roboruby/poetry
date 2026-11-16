# frozen_string_literal: true

# installed by the poetry `screen-chat-ruby-llm` recipe - this file is
# yours. A message in a conversation that already exists.
#
# The answer is only a status, which is all the composer reads: any
# success clears the sent text from the field, anything else leaves it.
# The rows and the action slot reach the page through ChatStream.
class MessagesController < ApplicationController
  before_action :set_chat

  def create
    content = params[:message].to_s.strip
    return head(422) if content.empty?
    # One turn at a time: the composer refuses a send while Stop shows,
    # and the server refuses it as well.
    return head(:conflict) if @chat.responding?

    @chat.add_message(role: :user, content: content)
    @chat.begin_turn!
    stream = ChatStream.new(@chat)
    stream.show(@chat.messages.order(:id).last)
    stream.action
    ChatResponseJob.perform_later(@chat.id)
    head :no_content
  end

  private

  def set_chat
    @chat = Chat.find(params[:chat_id])
  end
end
