# frozen_string_literal: true

module Poetry
  module Agent
    module MCP
      # The server as the exe assembles it: the registry root defaults to
      # the bundled poetry-ui gem, poetry-lucide's icon names power check's
      # icon-membership tier, and poetry-ui's skills, helper names, and
      # recipes ride along when the gem is bundled - each a soft require,
      # so the same assembly serves a core-only host. ONE assembly for the
      # exe and the HTTP mount, so no surface can lag another.
      module Bundled
        module_function

        # @param root [String, nil] one more registry root to serve (the
        #   bundle's published registries and the app's committed one are
        #   found on their own)
        # @param app_root [String] the host app (its committed registry, when
        #   `bin/rails poetry:registry` wrote one; build_page's probe/direct
        #   steps read its config/theme)
        # @return [Server]
        # @raise [ArgumentError] when no component registry is found
        def server(root: nil, app_root: Dir.pwd)
          ui = soft_require("poetry/ui")
          roots = Poetry::Core::Registry.gem_roots(app_root: app_root).map(&:to_s)
          # Controllers manifests by the same convention, boot-free: every
          # bundled gem's and the app's own, so the check tool validates
          # chart, agent and host controllers like core's.
          manifest_roots = Poetry::Core::Registry.gem_roots(app_root: app_root, registry: false)
          Poetry::Core::Stimulus::Manifest.register_roots(manifest_roots)
          roots.unshift(root) if root && !roots.include?(root)
          raise ArgumentError, "no published component registry in the bundle - pass a root" if roots.empty?

          skills, helpers, recipes =
            if ui
              [Poetry::Ui.agent_skills(app_root: app_root), Poetry::Ui.helper_names, Poetry::Ui.recipe_items.summaries]
            else
              [{}, nil, []]
            end
          # The valid helper set: the registries' own sections carry every
          # gem helper and the app's declared ones; poetry-ui's live names
          # ride along when the gem is loaded, for a registry that predates
          # the sections.
          Server.from_registries(roots, icon_names: icon_names, helpers: helpers, skills: skills,
                                        app_root: app_root, recipes: recipes)
        end

        # The lucide names, or nil for a host without poetry-lucide (check
        # then validates icon-name shape only).
        def icon_names
          return nil unless soft_require("poetry/lucide")

          Poetry::Core::Icons.set(:lucide).names
        rescue Poetry::Core::Error
          nil
        end

        # Requires a feature and answers whether it loaded.
        def soft_require(feature)
          require feature
          true
        rescue LoadError
          false
        end

        private_class_method :soft_require
      end
    end
  end
end
