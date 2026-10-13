# frozen_string_literal: true

require "pathname"
require "poetry/core"
require "yaml"
require_relative "motion/version"

Poetry::Core::CSS::Modes.pin("Poetry::Motion", :tailwind)

# The motion behaviors resolve by name beside poetry-core's.
Poetry::Core::Behavior.namespaces << "Poetry::Motion::Behaviors"

module Poetry
  # poetry-motion: opt-in animated effects. The server renders each
  # effect's finished state; the vendored animation engine
  # (`@poetry/motion/engine`) is pinned without preload and fetched by a
  # dynamic import the first time an element asks for it, so a page with no
  # motion element loads none of it. One policy module
  # (`@poetry/motion/policy`) owns reduced motion, the motion tokens, the
  # Turbo cache flush and the one view-transition slot.
  module Motion
    # The gem root.
    #
    # @return [Pathname]
    def self.root
      @root ||= Pathname.new(File.expand_path("../..", __dir__))
    end

    # The agent-surface registry of the effects (the poetry-charts pattern):
    # config/component_registry.yml, generated from source and drift-gated.
    #
    # @return [Poetry::Core::Registry]
    def self.registry
      Poetry::Core::Registry.new(source_root: root, helper_args: registry_helper_args,
                                 descriptions: YAML.safe_load_file(root.join("config/component_descriptions.yml")))
    end

    # Each poetry_* helper's positional arity, read from its signature.
    #
    # @return [Hash{String => Integer}]
    def self.registry_helper_args
      require root.join("app/helpers/poetry/motion/components_helper.rb")
      ComponentsHelper.public_instance_methods(false).grep(/\Apoetry_/).sort.to_h do |name|
        params = ComponentsHelper.instance_method(name).parameters
        [name.to_s, params.count { |kind, _| %i[req opt].include?(kind) }]
      end
    end
  end
end

require_relative "motion/engine" if defined?(Rails::Engine)
