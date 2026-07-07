# frozen_string_literal: true

Rails.application.routes.draw do
  # The eval capture rig (rake eval:capture) screenshots the frozen eval
  # arms at these pages; constraints keep the params filename-shaped.
  get "/eval/:task/:arm", to: "eval_arms#show",
                          constraints: { task: /[a-z0-9_]+/, arm: /[a-z0-9_]+/ }

  mount Poetry::Ui::Engine => "/"
end
