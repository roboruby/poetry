# frozen_string_literal: true

Rails.application.routes.draw do
  mount Poetry::Ui::Engine => "/poetry" # llms.txt + llms-full.txt (agent-facing docs)
  get "up" => "rails/health#show", as: :rails_health_check
  # The screen-chat recipe's routes, as its description gives them: the
  # recipe is run as a host would have it by
  # test/controllers/screen_chat_recipe_test.rb, which loads its files.
  if Rails.env.test?
    resource :chat, only: %i[show create] do
      post :stop
    end
  end
  mount Poetry::Docs::Engine => "/"
end
