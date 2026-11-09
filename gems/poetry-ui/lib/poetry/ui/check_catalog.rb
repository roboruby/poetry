# frozen_string_literal: true

module Poetry
  module Ui
    # The host's check catalog, built the one way `poetry:check` and
    # `poetry:audit` share: every published registry in the boot (poetry-ui,
    # poetry-charts, any engine on the DSL that committed one, the app's own
    # file), the app's own components and `poetry_*` helper methods, and
    # every registered icon set with its aliases.
    module CheckCatalog
      module_function

      # The catalog for an app.
      #
      # @param root [Pathname, String] the app root
      # @return [Poetry::Core::Check::Catalog]
      def build(root:)
        # The active set's names light up membership validation (the value
        # contract) and the declaration tier; a host without a registered
        # set still checks icon-name shape.
        icon_names = begin
          Poetry::Core::Icons.set.names
        rescue Poetry::Core::Error
          nil
        end
        # Every registered set by key: a call naming its set (library:
        # :tabler) is checked against that set rather than the active one;
        # renamed names render through a set's aliases.
        icon_libraries = Poetry::Core::Icons.registry.transform_values(&:names)
        icon_library_aliases = Poetry::Core::Icons.registry.transform_values do |set|
          set.respond_to?(:aliases) ? set.aliases : {}
        end
        icon_aliases = icon_library_aliases.fetch(Poetry::Core::Config.current.icon_library.to_sym, {})
        # The app's own components (`helper :name` on the DSL) and its own
        # poetry_* helper methods join the valid set with contracts of their
        # own, built live from the loaded classes, never a committed file.
        Poetry::Core::Check::Catalog.from_registries(
          Poetry::Core::Registry.roots,
          icon_names: icon_names,
          host_registry: Poetry::Core::HostComponents.registry(root: root),
          host_helpers: Poetry::Core::HostComponents.helper_methods(root: root),
          icon_libraries: icon_libraries, icon_aliases: icon_aliases, icon_library_aliases: icon_library_aliases
        )
      end
    end
  end
end
