# frozen_string_literal: true

require "poetry/core"
require_relative "ui/version"

module Poetry
  # The component library: shadcn-parity ViewComponents built entirely on
  # poetry-core's PUBLIC DSL - if a component here needs private core API,
  # that is a core API gap, not a license to reach in (dogfooding).
  module Ui
    # The committed static-template-class list (herb-extracted in poetry's
    # CI, drift-gated) - poetry:install reads it so hosts never need herb.
    TEMPLATE_CLASSES_PATH = "config/template_classes.txt"

    class << self
      # Gem root (the directory containing lib/, app/, config/).
      def root
        @root ||= Pathname.new(File.expand_path("../..", __dir__))
      end

      # @return [Array<String>] the committed template-static classes
      def template_classes
        root.join(TEMPLATE_CLASSES_PATH).read.lines
            .map(&:strip).reject { |line| line.empty? || line.start_with?("#") }
      end

      # The public poetry_* helper names, scanned from the ComponentsHelper
      # source so poetry check / poetry-agent know the full set (group /
      # provider helpers included) WITHOUT booting Rails - the module isn't
      # loaded when the MCP server starts.
      def helper_names
        source = root.join("app/helpers/poetry/ui/components_helper.rb").read
        source.scan(/def (poetry_[a-z_]+)/).flatten.uniq
      end
    end
  end
end

require_relative "ui/engine"
