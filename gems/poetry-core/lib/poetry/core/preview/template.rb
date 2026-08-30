# frozen_string_literal: true

module Poetry
  module Core
    module Preview
      # Provides flexible template resolution for ViewComponent previews.
      # Adapted from an MIT-licensed source (source and license in
      # THIRD_PARTY_NOTICES.md).
      #
      # This module extends ViewComponent's preview template system to support multiple
      # template locations and fallback strategies. It allows previews to use:
      # - Example-specific templates (e.g., `previews/default.html.erb`)
      # - Shared preview templates (e.g., `preview.html.erb`)
      # - A configurable default template
      #
      # The template resolution follows this priority order:
      # 1. ViewComponent's standard template location (via super)
      # 2. Example-specific template: `preview_name/previews/example_name.html.*`
      # 3. Preview-level template: `preview_name/preview.html.*`
      # 4. Default template (configurable, defaults to "poetry/core/preview")
      #
      # @example Basic usage with default template
      #   class ButtonPreview < Poetry::Core::Preview::Base
      #     # Uses the default template (poetry/core/preview)
      #     def default
      #       render_component(text: "Click me")
      #     end
      #   end
      #
      # @example Using example-specific template
      #   # File: test/components/previews/button_preview.rb
      #   class ButtonPreview < Poetry::Core::Preview::Base
      #     def complex
      #       render_with(button: ButtonComponent.new)
      #     end
      #   end
      #
      #   # Template: test/components/previews/button_preview/previews/complex.html.erb
      #   <div class="preview-container">
      #     <%= render @button %>
      #     <p>Additional markup for this specific preview</p>
      #   </div>
      #
      # @example Using shared preview template
      #   # File: test/components/previews/card_preview.rb
      #   class CardPreview < Poetry::Core::Preview::Base
      #     def basic; render_component; end
      #     def featured; render_component(featured: true); end
      #   end
      #
      #   # Template: test/components/previews/card_preview/preview.html.erb
      #   # This template is shared by all examples in this preview
      #   <div class="card-demo-wrapper">
      #     <%= render @component %>
      #   </div>
      #
      # @example Configuring custom default template
      #   class MyBasePreview < Poetry::Core::Preview::Base
      #     self.default_preview_template = "my_app/custom_preview"
      #   end
      #
      #   class ButtonPreview < MyBasePreview
      #     # Inherits the custom default template
      #     def default
      #       render_component
      #     end
      #   end
      #
      # @see Poetry::Core::Preview::Base
      module Template
        # The default template path used when no specific template is found.
        #
        # This template is rendered for previews that don't have:
        # - A ViewComponent standard template
        # - An example-specific template
        # - A preview-level shared template
        #
        # @api public
        DEFAULT_TEMPLATE = "poetry/core/preview"

        # @api private
        def self.included(base)
          base.singleton_class.prepend(ClassMethods)
        end

        # Class-level methods added to preview classes when Template is included.
        #
        # These methods provide template configuration and resolution logic that
        # operates at the class level, allowing inheritance and customization.
        module ClassMethods
          # @!attribute [w] default_preview_template
          #   Sets the default template path for this preview class.
          #
          #   @return [String] the configured template path
          #
          #   @example
          #     class MyPreview < Poetry::Core::Preview::Base
          #       self.default_preview_template = "my_app/special_preview"
          #     end
          attr_writer :default_preview_template

          # Returns the default preview template path for this class.
          #
          # The template path is inherited from parent classes. If not explicitly set,
          # it walks up the class hierarchy until it finds a configured template or
          # falls back to {DEFAULT_TEMPLATE}.
          #
          # @return [String] the default template path
          #
          # @example Using default template
          #   Poetry::Core::Preview::Base.default_preview_template
          #   # => "poetry/core/preview"
          #
          # @example Custom template with inheritance
          #   class BasePreview < Poetry::Core::Preview::Base
          #     self.default_preview_template = "custom/layout"
          #   end
          #
          #   class ButtonPreview < BasePreview
          #   end
          #
          #   ButtonPreview.default_preview_template
          #   # => "custom/layout" (inherited from BasePreview)
          def default_preview_template
            return @default_preview_template if defined?(@default_preview_template)

            @default_preview_template =
              if superclass.respond_to?(:default_preview_template)
                superclass.default_preview_template
              else
                DEFAULT_TEMPLATE
              end
          end

          # Resolves the template path for a preview example with multiple fallbacks.
          #
          # This method implements a flexible template resolution strategy that tries
          # multiple locations in order:
          #
          # 1. First calls ViewComponent's default resolution (via super)
          # 2. If not found, looks for example-specific template at:
          #    `preview_name/previews/example_name.html.*`
          # 3. If not found, looks for shared preview template at:
          #    `preview_name/preview.html.*`
          # 4. Falls back to {#default_preview_template}
          #
          # This fallback behavior allows previews to share templates across examples
          # or use a common default template, reducing duplication.
          #
          # @param example [String] the name of the preview example method
          # @return [String] the resolved template path
          #
          # @example Template resolution for ButtonPreview#primary
          #   # Tries in order:
          #   # 1. ViewComponent default (e.g., test/components/previews/button_preview/primary.html.erb)
          #   # 2. test/components/previews/button_preview/previews/primary.html.erb
          #   # 3. test/components/previews/button_preview/preview.html.erb
          #   # 4. the default template (poetry/core/preview)
          #
          # @note The method searches across all configured preview_paths
          # @note Supports any template handler (erb, haml, slim, etc.)
          def preview_example_template_path(example)
            super
          rescue ViewComponent::MissingPreviewTemplateError
            # Look for example-specific template: preview_name/previews/example.html.*
            has_example_preview = preview_paths.find do |path|
              Dir.glob(File.join(path, preview_name, "previews", "#{example}.html.*")).any?
            end

            return File.join(preview_name, "previews", example) if has_example_preview

            # Look for shared preview template: preview_name/preview.html.*
            has_root_preview = preview_paths.find do |path|
              Dir.glob(File.join(path, preview_name, "preview.html.*")).any?
            end

            return File.join(preview_name, "preview") if has_root_preview

            # Fall back to configured default template
            default_preview_template
          end
        end
      end
    end
  end
end
