Rails.application.routes.draw do
  mount Poetry::Ui::Engine => "/poetry" # llms.txt + llms-full.txt (agent-facing docs)
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  get "docs" => "docs#index", as: :introduction
  get "installation" => "docs#installation", as: :installation
  get "theming" => "docs#theming", as: :theming
  get "typography" => "docs#typography", as: :typography
  get "deferred" => "docs#deferred", as: :deferred
  get "deferred/fragment" => "docs#deferred_fragment", as: :deferred_fragment
  get "optimistic-forms" => "docs#optimistic_forms", as: :optimistic_forms
  get "forms" => "docs#forms", as: :forms
  get "pagination" => "docs#pagination", as: :pagination
  post "optimistic-forms/favorite" => "docs#optimistic_favorite", as: :optimistic_favorite
  post "optimistic-forms/rejected" => "docs#optimistic_rejected", as: :optimistic_rejected
  get "editors" => "docs#editors", as: :editors
  get "testing" => "docs#testing", as: :testing
  get "accessibility" => "docs#accessibility", as: :accessibility
  get "caching" => "docs#caching", as: :caching
  get "stable-ids" => "docs#stable_ids", as: :stable_ids
  get "data-table" => "docs#data_table", as: :data_table_guide
  get "mcp" => "docs#mcp", as: :mcp
  get "libraries/:slug" => "docs#library", as: :library, constraints: { slug: /[a-z-]+/ }
  get "icons/:slug" => "docs#icon_set", as: :icon_set, constraints: { slug: /[a-z-]+/ }
  get "recipes" => "docs#recipes", as: :recipes
  get "agent" => "docs#agent", as: :agent
  get "operator-register.json" => "machine#operator_register", format: false

  # The official registry - shadcn-schema items served live from the gem
  # registries; literal routes before the catch.
  get "r/registry.json" => "registry#index", as: :registry_index
  get "r/registries.json" => "registry#directory", as: :registry_directory
  get "r/:name" => "registry#show", as: :registry_item, format: false,
                   constraints: { name: /[a-z0-9.-]+\.json/ }

  # Web-installable Agent Skills: poetry's own inventory (index +
  # per-file) at /.well-known/skills, the settled discovery convention at
  # /.well-known/agent-skills - the agent-skills discovery RFC
  # (schemas.agentskills.io/discovery/0.2.0) with a payload url and sha256
  # digest per skill - and the payloads + human catalog page under
  # /agent-skills, one prefix so `npx skills add <site-url>/agent-skills`
  # finds every entry when it scopes by path. All of it serves from the
  # same generators the installed skills use.
  get "/.well-known/skills/index.json" => "skills#index", as: :skills_index, format: false
  get "/.well-known/skills/:skill/*file" => "skills#show", as: :skill_file, format: false,
      constraints: { skill: /[a-z-]+/ }
  get "/.well-known/agent-skills/index.json" => "skills#discovery", as: :skills_discovery, format: false
  get "/.well-known/agent-skills/:skill/*file" => "skills#show", format: false,
      constraints: { skill: /[a-z-]+/ }
  get "agent-skills" => "docs#agent_skills", as: :agent_skills
  # Path-scoped discovery: handed <origin>/agent-skills, the installer
  # looks for the index UNDER that prefix (both spellings) and refuses to
  # fall back to the root index, so the same document answers here.
  get "agent-skills/.well-known/agent-skills/index.json" => "skills#discovery", format: false
  get "agent-skills/.well-known/skills/index.json" => "skills#discovery", format: false
  get "agent-skills/:skill" => "skills#archive", as: :skill_archive, format: false,
      constraints: { skill: /[a-z-]+\.tar\.gz/ }
  get "agent-skills/:skill/*file" => "skills#show", format: false,
      constraints: { skill: /[a-z-]+/ }

  # The agent-legibility discovery surfaces: the root llms.txt site index,
  # the OpenAPI description of the machine endpoints, and the RFC 9727
  # catalog pointing at it.
  get "llms.txt" => "docs#llms", as: :llms, format: false
  get "sitemap.xml" => "machine#sitemap", as: :sitemap, format: false
  get "robots.txt" => "machine#robots", format: false
  get "llms-full.txt" => redirect("/poetry/llms-full.txt", status: 302), format: false
  get "openapi.json" => "machine#openapi", as: :openapi, format: false
  get "/.well-known/api-catalog" => "machine#api_catalog", as: :api_catalog, format: false

  get "examples/:section/:slug/:name" => "examples#show", as: :standalone_example, format: false,
      constraints: { section: /components|charts|demos|docs/, slug: /[a-z0-9-]+/, name: /[a-z0-9_]+/ }
  get "examples/blocks/:slug" => "examples#block", as: :standalone_block, format: false,
      constraints: { slug: /[a-z0-9-]+/ }

  # The API reference: framework-surface pages generated from the gems'
  # YARD exports (data/api/*.json via docs:api_reference).
  get "api" => "api#index", as: :api_index
  get "api/:slug" => "api#show", as: :api_page, constraints: { slug: /[a-z_-]+/ }

  get "components/:slug" => "components#show", as: :component
  get "charts/:slug" => "charts#show", as: :chart
  get "blocks/:slug" => "blocks#show", as: :block
  get "demos/chat-replay/stream" => "chat_replay#stream", as: :chat_replay_stream, format: false
  get "demos/:slug" => "demos#show", as: :demo

  # The marketing landing page owns the root; the docs shell starts at /docs.
  root "landing#show"
end
