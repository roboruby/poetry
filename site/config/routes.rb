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
  get "deferred" => "docs#deferred", as: :deferred
  get "deferred/fragment" => "docs#deferred_fragment", as: :deferred_fragment

  # The official registry (Ecosystem v1) - shadcn-schema items
  # served live from the gem registries; literal routes before the catch.
  get "r/registry.json" => "registry#index", as: :registry_index
  get "r/registries.json" => "registry#directory", as: :registry_directory
  get "r/:name" => "registry#show", as: :registry_item, format: false,
                   constraints: { name: /[a-z0-9.-]+\.json/ }

  get "components/:slug" => "components#show", as: :component
  get "charts/:slug" => "charts#show", as: :chart
  get "blocks/:slug" => "blocks#show", as: :block
  get "demos/:slug" => "demos#show", as: :demo

  # Defines the root path route ("/")
  root "docs#index"
end
