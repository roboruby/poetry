# frozen_string_literal: true

module Poetry
  module Core
    # The host application's own components: classes written on the
    # Poetry DSL that live under the app root (never the gems' copies,
    # which `poetry:add` places under the gem namespace and the gem
    # registries already describe). Discovery is convention, not
    # configuration: a Component descendant whose source sits under
    # `<root>/app` and whose path does not start with `poetry/` belongs to
    # the app. The class names its view helper with `helper :name`; the
    # engine defines that helper on Action View at boot and on every
    # reload, and the booted surfaces (`poetry:check`, llms.txt, the
    # generated skill) read the app's registry built here.
    #
    # @example
    #   Poetry::Core::HostComponents.registry(root: Rails.root).entries.keys # => ["demo/badge"]
    #
    # @api private
    module HostComponents
      # Paths under this prefix belong to a poetry gem (or a copy of one).
      GEM_PREFIX = "poetry/"
      # The `helper :name` declaration, as source text - the boot-free
      # read (the MCP server's check tool) scans component files for it.
      DECLARATION = /^\s*helper\s+:([a-z_][a-z0-9_]*)\b/

      module_function

      # Every app component class, loaded. The components directory is
      # eager-loaded first where an autoloader exists: `descendants` sees
      # only loaded classes, and lazy autoloading would otherwise make the
      # set depend on which views rendered so far.
      #
      # @param root [String, Pathname] the app root
      # @return [Array<Class>]
      def discover(root:)
        root = Pathname.new(root)
        components_dir = root.join("app/components")
        loader = defined?(Rails) && Rails.respond_to?(:autoloaders) && Rails.autoloaders.main
        # Only a directory the autoloader manages can be eager-loaded (a
        # root outside the app, as in a test, is loaded by its caller).
        loader.eager_load_dir(components_dir) if loader&.dirs&.include?(components_dir.to_s)
        select(Poetry::Core::Component.descendants, root: root)
      end

      # The app's own components among `components`: named, published (not
      # internal), defined under `<root>/app`, outside the gem namespace.
      #
      # @param components [Enumerable<Class>]
      # @param root [String, Pathname]
      # @return [Array<Class>] sorted by name
      def select(components, root:)
        app_root = Pathname.new(root).join("app").to_s
        components.select(&:name).reject(&:internal_component).select do |component|
          next false if component.component_path.start_with?(GEM_PREFIX)

          path = Object.const_source_location(component.name)&.first
          path&.start_with?(app_root)
        end.sort_by(&:name)
      end

      # The app's registry, built live from its loaded classes - the same
      # entry contract as a gem registry (options, styles, parts, agent
      # rules, wiring), plus the declared helper per entry. Helpers the
      # engine defines take keywords only, so the arity map says so and
      # `poetry check` flags a positional argument.
      #
      # @param root [String, Pathname] the app root
      # @return [Registry]
      def registry(root:)
        components = discover(root: root)
        helper_args = components.filter_map { |component| [component.helper_name, 0] if component.helper_name }.to_h
        Registry.new(components: components, source_root: root, helper_args: helper_args)
      end

      # The declared helper names, boot-free: a source scan of the app's
      # component files for `helper :name`, for consumers that never load
      # the classes (the MCP server's check tool, which runs without
      # Rails). The booted surfaces read {.registry} instead.
      #
      # @param root [String, Pathname] the app root
      # @return [Array<String>] sorted, unique
      def declared_helpers(root:)
        Dir.glob(Pathname.new(root).join("app/components/**/*.rb").to_s).flat_map do |file|
          File.read(file).scan(DECLARATION).flatten
        end.uniq.sort
      end
    end
  end
end
