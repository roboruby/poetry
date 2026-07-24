Rails.application.routes.draw do
  mount Poetry::Ui::Engine => "/poetry" # llms.txt + llms-full.txt (agent-facing docs)
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  get "installation" => "docs#installation", as: :installation
  get "theming" => "docs#theming", as: :theming
  get "typography" => "docs#typography", as: :typography
  get "deferred" => "docs#deferred", as: :deferred
  get "deferred/fragment" => "docs#deferred_fragment", as: :deferred_fragment
  get "optimistic-forms" => "docs#optimistic_forms", as: :optimistic_forms
  post "optimistic-forms/favorite" => "docs#optimistic_favorite", as: :optimistic_favorite
  post "optimistic-forms/rejected" => "docs#optimistic_rejected", as: :optimistic_rejected
  get "editors" => "docs#editors", as: :editors

  # The official registry (Ecosystem v1) - shadcn-schema items
  # served live from the gem registries; literal routes before the catch.
  get "r/registry.json" => "registry#index", as: :registry_index
  get "r/registries.json" => "registry#directory", as: :registry_directory
  get "r/:name" => "registry#show", as: :registry_item, format: false,
                   constraints: { name: /[a-z0-9.-]+\.json/ }

  # Web-installable Agent Skills: discovery index + skill files,
  # served from the same generators the installed skills use.
  get "/.well-known/skills/index.json" => "skills#index", as: :skills_index, format: false
  get "/.well-known/skills/:skill/*file" => "skills#show", as: :skill_file, format: false,
      constraints: { skill: /[a-z-]+/ }

  get "components/:slug" => "components#show", as: :component
  get "charts/:slug" => "charts#show", as: :chart
  get "blocks/:slug" => "blocks#show", as: :block
  get "demos/:slug" => "demos#show", as: :demo

  # Defines the root path route ("/")
  root "docs#index"
end
