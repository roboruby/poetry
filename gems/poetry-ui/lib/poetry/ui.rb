# frozen_string_literal: true

require "poetry/core"
require_relative "ui/version"
require_relative "ui/themes"

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

      # The public poetry_* helper names, so poetry check / poetry-agent know
      # the full set (group / provider helpers AND the define_method'd part
      # helpers like poetry_table_cell) WITHOUT booting Rails. The module's
      # method bodies reference component constants only at call time, so
      # requiring the file standalone is safe.
      def helper_names
        require root.join("app/helpers/poetry/ui/components_helper.rb")
        ComponentsHelper.public_instance_methods(false).grep(/\Apoetry_/).map(&:to_s)
      rescue StandardError
        # Fallback: the static-def helpers (misses define_method ones) if the
        # module can't load standalone in some host.
        root.join("app/helpers/poetry/ui/components_helper.rb").read.scan(/def (poetry_[a-z_]+)/).flatten.uniq
      end
    end
  end
end

require_relative "ui/engine"
