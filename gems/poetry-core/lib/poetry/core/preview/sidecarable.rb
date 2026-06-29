# frozen_string_literal: true

module Poetry
  module Core
    # Adapted from https://github.com/palkan/view_component-contrib/blob/master/lib/view_component_contrib/preview/sidecarable.rb
    module Preview
      # Provides sidecar file loading and naming utilities for preview classes.
      #
      # This module adds functionality to automatically load preview files from configured paths
      # and derive component names from preview class names. It's designed to support the "sidecar"
      # pattern where preview files are organized alongside their corresponding components.
      #
      # The module extends preview classes (typically ViewComponent::Preview) and prepends class
      # methods that handle preview file discovery and name extraction, making it easier to organize
      # and load previews in a consistent, convention-based manner.
      #
      # @example Basic usage with ViewComponent::Preview
      #   ViewComponent::Preview.extend Poetry::Core::Preview::Sidecarable
      #
      #   # Load all preview files from configured paths
      #   ViewComponent::Preview.load_previews
      #
      # @example Preview name extraction
      #   class MyApp::Button::Preview < ViewComponent::Preview
      #     extend Poetry::Core::Preview::Sidecarable
      #   end
      #
      #   MyApp::Button::Preview.preview_name
      #   # => "my_app/button"
      #
      # @example Namespace variations
      #   class ButtonPreview < ViewComponent::Preview
      #     extend Poetry::Core::Preview::Sidecarable
      #   end
      #
      #   ButtonPreview.preview_name  # => "button"
      #
      #   class Admin::CardPreview < ViewComponent::Preview
      #     extend Poetry::Core::Preview::Sidecarable
      #   end
      #
      #   Admin::CardPreview.preview_name  # => "admin/card"
      #
      # @note Preview files are discovered using the glob pattern `**/{preview.rb,*_preview.rb}`,
      #   which matches both standalone `preview.rb` files and files ending with `_preview.rb`.
      #
      module Sidecarable
        # Glob pattern for discovering preview files.
        #
        # Matches:
        # - `preview.rb` - Standalone preview files
        # - `*_preview.rb` - Named preview files (e.g., `button_preview.rb`)
        #
        # @return [String] the glob pattern for preview file discovery
        PREVIEW_GLOB = "**/{preview.rb,*_preview.rb}"

        # Hook method called when this module is extended into a class.
        #
        # Prepends ClassMethods to the class's singleton class, making the sidecar loading
        # functionality available to the extending class.
        #
        # @param base [Class] the class being extended with this module
        # @return [void]
        # @api private
        def self.extended(base)
          base.singleton_class.prepend(ClassMethods)
        end

        # Class methods added to preview classes that extend the Sidecarable module.
        #
        # These methods provide preview file loading and component name extraction functionality.
        module ClassMethods
          # Loads all preview files from configured preview paths.
          #
          # Iterates through each configured preview path and requires all files matching
          # the PREVIEW_GLOB pattern. Files are loaded in sorted order to ensure consistent
          # loading sequence across environments.
          #
          # @return [void]
          # @example Loading previews
          #   ViewComponent::Preview.preview_paths = ["app/components"]
          #   ViewComponent::Preview.load_previews
          #   # Loads: app/components/**/preview.rb
          #   #        app/components/**/*_preview.rb
          #
          # @example With multiple paths
          #   ViewComponent::Preview.preview_paths = [
          #     "app/components",
          #     "app/views/components"
          #   ]
          #   ViewComponent::Preview.load_previews
          #   # Loads previews from both directories
          #
          # @note Uses `require_dependency` to ensure proper reloading in development mode.
          def load_previews
            Array(preview_paths).each do |preview_path|
              Dir["#{preview_path}/#{PREVIEW_GLOB}"].each { |file| require_dependency file }
            end
          end

          # Extracts the component name from the preview class name.
          #
          # Removes the "Preview" or "::Preview" suffix from the class name and converts
          # it to underscore/snake_case format. This is useful for deriving file paths,
          # identifiers, and component names from preview class names.
          #
          # @return [String] the underscored component name
          # @example Basic usage
          #   class ButtonPreview < ViewComponent::Preview
          #     extend Poetry::Core::Preview::Sidecarable
          #   end
          #
          #   ButtonPreview.preview_name  # => "button"
          #
          # @example With namespace
          #   class Admin::Dashboard::CardPreview < ViewComponent::Preview
          #     extend Poetry::Core::Preview::Sidecarable
          #   end
          #
          #   Admin::Dashboard::CardPreview.preview_name  # => "admin/dashboard/card"
          #
          # @example With trailing Preview namespace
          #   class Components::Alert::Preview < ViewComponent::Preview
          #     extend Poetry::Core::Preview::Sidecarable
          #   end
          #
          #   Components::Alert::Preview.preview_name  # => "components/alert"
          def preview_name
            name.sub(/(::Preview|Preview)$/, "").underscore
          end
        end
      end
    end
  end
end
