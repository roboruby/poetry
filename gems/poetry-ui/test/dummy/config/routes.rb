# frozen_string_literal: true

Rails.application.routes.draw do
  # The eval capture rig (rake eval:capture) screenshots the frozen eval
  # arms at these pages; constraints keep the params filename-shaped.
  get "/eval/:task/:arm", to: "eval_arms#show",
                          constraints: { task: /[a-z0-9_]+/, arm: /[a-z0-9_]+/ }

  # The block previews (Blocks v1): the browser tiers hold every shipped
  # block to the same axe + golden gates as the component previews.
  get "/blocks/:name", to: "blocks#show", constraints: { name: /[a-z0-9_]+/ }

  mount Poetry::Ui::Engine => "/"
end
