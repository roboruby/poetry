Rails.application.routes.draw do
  mount Poetry::Ui::Engine => "/poetry" # llms.txt + llms-full.txt (agent-facing docs)
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  get "theming" => "docs#theming", as: :theming
  get "typography" => "docs#typography", as: :typography

  get "components/:slug" => "components#show", as: :component
  get "charts/:slug" => "charts#show", as: :chart
  get "demos/:slug" => "demos#show", as: :demo

  # Defines the root path route ("/")
  root "docs#index"
end
