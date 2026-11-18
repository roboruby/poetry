# frozen_string_literal: true

# installed by the poetry `screen-chat-ruby-llm` recipe - this file is
# yours: edit freely. It needs RubyLLM 2 with its models installed
# (`bin/rails g ruby_llm:install`), and three things of yours:
#
#   # config/routes.rb
#   resources :chats, only: %i[new create show] do
#     post :stop, on: :member
#     resources :messages, only: :create
#   end
#
#   # app/models/chat.rb, beside acts_as_chat
#   include ChatTurn
#
#   # a column for the turn (a migration of your own, so it runs after
#   # the one that creates your chats table)
#   bin/rails g migration AddRespondingSinceToChats responding_since:datetime
#   bin/rails db:migrate
#
# A conversation with a model, on the chat block (installed alongside at
# app/views/blocks/_chat.html.erb). A message is stored, the turn is
# recorded on the chat, and ChatResponseJob writes the reply into the
# page as the model writes it. Stop asks RubyLLM to cancel; the job hears
# it at the next chunk, in whatever process it runs.
class ChatsController < ApplicationController
  before_action :set_chat, only: %i[show stop]

  # A new conversation: the block on its welcome, its composer posting to create.
  def new; end

  # POST: the first message of a new conversation.
  def create
    content = params[:message].to_s.strip
    return head(422) if content.empty?

    # RubyLLM's default model. Name another, and its provider when the
    # model has several: Chat.create!(model: "...", provider: "...").
    chat = Chat.create!
    chat.add_message(role: :user, content: content)
    chat.begin_turn!
    ChatResponseJob.perform_later(chat.id)
    redirect_to chat, status: :see_other
  end

  def show
    @messages = @chat.messages.where(role: %w[user assistant]).order(:id)
  end

  # POST: Stop. With a reply running, the request is recorded and the job
  # ends the turn. With none (a page left on Stop by a broadcast it
  # missed), the slot is drawn as it stands.
  def stop
    if @chat.responding?
      @chat.cancel
      ChatStream.new(@chat).action
      head :no_content
    else
      render turbo_stream: turbo_stream.replace("chat-action", partial: "chats/composer_action",
                                                               locals: { status: :idle })
    end
  end

  private

  def set_chat
    @chat = Chat.find(params[:id])
  end
end
