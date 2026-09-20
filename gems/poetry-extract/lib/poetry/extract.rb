# frozen_string_literal: true

require "poetry/core"
require_relative "extract/version"
require_relative "extract/derive_tokens"
require_relative "extract/fetch"
require_relative "extract/compose"
require_relative "extract/runner"

# The poetry namespace.
module Poetry
  # The optional design-extraction gem: domain in, theme out. Produces a
  # DESIGN.md + deterministic token stylesheets and hands them to
  # poetry-core's AA-gated design importer - never the theme directly.
  module Extract
    # The gem's one error class: fetch, compose, and write failures all
    # raise it (missing API keys included).
    class Error < StandardError; end
  end
end

require_relative "extract/railtie" if defined?(Rails::Railtie)
