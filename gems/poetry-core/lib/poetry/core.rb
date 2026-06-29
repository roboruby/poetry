# frozen_string_literal: true

require_relative "core/version"

module Poetry
  # The framework layer of poetry: the Rails engine, the component DSL, and the
  # shared primitives. Concrete components live in poetry-ui.
  module Core
    class Error < StandardError; end

    # Engine, autoloading, and the component DSL are wired in during M0/U2.
  end
end
