# frozen_string_literal: true

# poetry-charts' importmap pins (the importmap-first channel): the
# host app's importmap merges these, so the tooltip chrome runs with zero
# build. Bundler hosts use the @poetry/charts npm package instead - one
# source, two channels.

pin "@poetry/charts", to: "poetry/charts/index.js"
pin_all_from File.expand_path("../app/javascript/poetry/charts", __dir__),
             under: "@poetry/charts", to: "poetry/charts"
