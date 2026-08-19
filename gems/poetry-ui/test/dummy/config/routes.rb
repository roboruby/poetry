# frozen_string_literal: true

Rails.application.routes.draw do
  # The eval capture rig (rake eval:capture) screenshots the frozen eval
  # arms at these pages; constraints keep the params filename-shaped.
  get "/eval/:task/:arm", to: "eval_arms#show",
                          constraints: { task: /[a-z0-9_]+/, arm: /[a-z0-9_]+/ }

  # The block previews (Blocks v1): the browser tiers hold every shipped
  # block to the same axe + golden gates as the component previews.
  get "/blocks/:name", to: "blocks#show", constraints: { name: /[a-z0-9_]+/ }

  # The Lookbook browser over the sidecar preview corpus ("one corpus,
  # three uses"): param controls, source panes, and the same
  # component_preview layout the browser gates screenshot.
  mount Lookbook::Engine => "/lookbook" if defined?(Lookbook)

  # Pagination-adapter hosts (test/poetry/ui/pagination_adapters_test.rb).
  # Drawn here permanently because runtime route mutation is unreliable in
  # this suite: mutating at require time trips the Rails 8 lazy route set
  # into a mid-suite reload that strands the engines' autoloaded constants,
  # and additive draws from test setup get wiped by later route reloads.
  # The controller is defined by the test file; the routes are inert
  # otherwise (drawing to an undefined controller only fails at dispatch).
  # The StableId architectural gate (rake test:morph_identity) - permanent
  # for the same reload-safety reason as /phost below.
  get "/sgate" => "stable_id_gate#index"

  get "/phost/kaminari" => "pagination_host#kaminari_page"
  get "/phost/kaminari_options" => "pagination_host#kaminari_options_page"
  get "/phost/pagy" => "pagination_host#pagy_page"
  get "/phost/will_paginate" => "pagination_host#will_paginate_page"

  mount Poetry::Ui::Engine => "/"
end
