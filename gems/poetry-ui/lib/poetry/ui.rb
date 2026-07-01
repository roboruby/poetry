# frozen_string_literal: true

require "poetry/core"
require_relative "ui/version"

module Poetry
  # The component library: shadcn-parity ViewComponents built entirely on
  # poetry-core's PUBLIC DSL - if a component here needs private core API,
  # that is a core API gap, not a license to reach in (dogfooding).
  module Ui
    class << self
      # Gem root (the directory containing lib/, app/, config/).
      def root
        @root ||= Pathname.new(File.expand_path("../..", __dir__))
      end
    end
  end
end

require_relative "ui/engine"
