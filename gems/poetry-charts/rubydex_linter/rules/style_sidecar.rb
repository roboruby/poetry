# frozen_string_literal: true

module Rubydex
  module Linter
    module Rules
      # Every component class has its Style sidecar. Poetry finds a
      # component's dictionary by convention (X::Component beside X::Style),
      # so a family without the sidecar renders with no class attribute at
      # all and no message. The families that render unstyled on purpose
      # (template-less, or a wrapper with no class of its own) are listed.
      class StyleSidecar < CustomRule
        NAMESPACE = "Poetry::Charts"
        PATTERN = /\A#{NAMESPACE}::(\w+)::Component\z/
        UNSTYLED = [].freeze

        class << self
          def default_severity
            Severity::Error
          end
        end

        def lint
          graph.declarations.each do |declaration|
            next unless declaration.is_a?(Rubydex::Class)

            match = declaration.name.match(PATTERN)
            next unless match
            next if UNSTYLED.include?(match[1])
            next if graph["#{NAMESPACE}::#{match[1]}::Style"]

            add_diagnostic("#{declaration.name} has no #{match[1]}::Style sidecar: it renders with no classes",
                           diagnostic_location(declaration.definitions.first))
          end
        end
      end
    end
  end
end
