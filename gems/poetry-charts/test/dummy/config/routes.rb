# frozen_string_literal: true

Rails.application.routes.draw do
  # Previews mount here when the browser rig lands (W1 frame components).
  root to: proc { [200, { "Content-Type" => "text/plain" }, ["poetry-charts dummy"]] }
end
