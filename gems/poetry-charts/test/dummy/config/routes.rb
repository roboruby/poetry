# frozen_string_literal: true

Rails.application.routes.draw do
  root to: proc { [200, { "Content-Type" => "text/plain" }, ["poetry-charts dummy"]] }

  # The interactive-chart doctrine demo: a real form, a server re-render.
  get "/interactive", to: "demo#interactive"
end
