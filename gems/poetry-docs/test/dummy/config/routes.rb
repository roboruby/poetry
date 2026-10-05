# frozen_string_literal: true

Rails.application.routes.draw do
  mount Poetry::Ui::Engine => "/poetry" # llms.txt + llms-full.txt (agent-facing docs)
  get "up" => "rails/health#show", as: :rails_health_check
  mount Poetry::Docs::Engine => "/"
end
