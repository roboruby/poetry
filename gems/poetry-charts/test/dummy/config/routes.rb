# frozen_string_literal: true

Rails.application.routes.draw do
  root to: proc { [200, { "Content-Type" => "text/plain" }, ["poetry-charts dummy"]] }

  # The interactive-chart doctrine demo: a real form, a server re-render.
  get "/interactive", to: "demo#interactive"

  # The live-mode demo: a streaming ticker feeding the client
  # renderer through the payload-script channel - zero server round trips.
  get "/live", to: "demo#live"

  # The C-W4 demo: two sync-grouped charts + an interactive legend.
  get "/sync", to: "demo#sync"

  # The C-W5 demo: brush + drag-zoom over the live window.
  get "/window", to: "demo#window"
end
