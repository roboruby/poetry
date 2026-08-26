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

        # @param root [String, nil] a registry root; defaults to poetry-ui
        # @param app_root [String] the host app (build_page's probe/direct
        #   steps read its config/theme)
        # @return [Server]
        # @raise [ArgumentError] when no component registry is found
        def server(root: nil, app_root: Dir.pwd)
          ui = soft_require("poetry/ui")
          root ||= ui ? Poetry::Ui.root.to_s : Gem::Specification.find_all_by_name("poetry-ui").first&.gem_dir
          registry = root && File.join(root, Poetry::Core::Registry::RELATIVE_PATH)
          unless registry && File.exist?(registry)
            raise ArgumentError, "no component registry at #{registry || "(no poetry-ui found)"} - pass root:"
          end

          skills, helpers, recipes =
            ui ? [Poetry::Ui.agent_skills, Poetry::Ui.helper_names, Poetry::Ui.recipe_items.summaries] : [{}, nil, []]
          Server.from_registry(root, icon_names: icon_names, helpers: helpers, skills: skills,
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

        # @api private
        def soft_require(feature)
          require feature
          true
        rescue LoadError
          false
        end
      end
    end
  end
end
