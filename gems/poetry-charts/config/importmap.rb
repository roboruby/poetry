# frozen_string_literal: true

# poetry-charts' importmap pins (the importmap-first channel): the
# host app's importmap merges these, so the tooltip chrome runs with zero
# build. Bundler hosts use the @poetry/charts npm package instead - one
# source, two channels.

pin "@poetry/charts", to: "poetry/charts/index.js"
pin_all_from Poetry::Core.javascript_path(File.expand_path("..", __dir__)).join("poetry/charts"),
             under: "@poetry/charts", to: "poetry/charts"
