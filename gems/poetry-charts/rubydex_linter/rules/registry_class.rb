# frozen_string_literal: true

require "yaml"

module Rubydex
  module Linter
    module Rules
      # Every class the component registry names is defined. The registry is
      # the machine-readable index agents and the check read; an entry whose
      # class_name no file defines is a stale or mistyped index line.
      class RegistryClass < CustomRule
        REGISTRY = "config/component_registry.yml"

        class << self
          def default_severity
            Severity::Error
          end
        end

        def lint
          return unless File.exist?(REGISTRY)

          names = []
          collect = lambda do |value|
            case value
            when Hash
              names << value["class_name"] if value["class_name"].is_a?(String)
              value.each_value { |inner| collect.call(inner) }
            when Array
              value.each { |inner| collect.call(inner) }
            end
          end
          collect.call(YAML.safe_load_file(REGISTRY, permitted_classes: [Symbol]))

          names.uniq.each do |name|
            next if graph[name]

            add_diagnostic("#{REGISTRY} names #{name}, which no file defines", nil)
          end
        end
      end
    end
  end
end
