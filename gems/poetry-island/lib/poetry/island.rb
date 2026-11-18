# frozen_string_literal: true

require "pathname"
require "poetry/core"
require "yaml"
require_relative "island/version"

Poetry::Core::CSS::Modes.pin("Poetry::Island", :tailwind)

module Poetry
  # poetry-island: a bounded client mount inside server-rendered HTML, the
  # one place in a Poetry page where the client owns the state. The server
  # renders a shell; the island's module, any file the importmap serves
  # that exports mount(element, props), mounts beside it on connect and
  # unmounts on disconnect. One controller handles the Turbo lifecycle for
  # every island: a morph refresh keeps the island and hands it the new
  # props, a cached snapshot's dead root is cleared, a preview shows the
  # shell, a failed import leaves the shell. State that must outlive the
  # page leaves through a form field rendered inside the island.
  module Island
    # The gem root.
    #
    # @return [Pathname]
    def self.root
      @root ||= Pathname.new(File.expand_path("../..", __dir__))
    end

    # The agent-surface registry (the poetry-motion pattern):
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
      require root.join("app/helpers/poetry/island/components_helper.rb")
      ComponentsHelper.public_instance_methods(false).grep(/\Apoetry_/).sort.to_h do |name|
        params = ComponentsHelper.instance_method(name).parameters
        [name.to_s, params.count { |kind, _| %i[req opt].include?(kind) }]
      end
    end
  end
end

require_relative "island/engine" if defined?(Rails::Engine)
