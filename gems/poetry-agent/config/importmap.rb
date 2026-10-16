# frozen_string_literal: true

# poetry-agent's importmap pins (the importmap-first channel): the host
# app's importmap merges these, so `import { registerPoetryAgent } from
# "@poetry/agent"` works with zero build. Bundler hosts use the
# @poetry/agent npm package instead - one source, two channels.

pin "@poetry/agent", to: "poetry/agent/index.js"
pin_all_from Poetry::Core.javascript_path(File.expand_path("..", __dir__)).join("poetry/agent"),
             under: "@poetry/agent", to: "poetry/agent"
