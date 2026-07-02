# frozen_string_literal: true

module Poetry
  module Core
    # Adapted from https://github.com/palkan/view_component-contrib/blob/master/lib/view_component_contrib/preview/base.rb
    module Preview
      # First, enable abstract classes (if not already extended)
      unless ViewComponent::Preview.singleton_class.is_a?(Preview::Abstract)
        ViewComponent::Preview.extend Preview::Abstract
      end

      # Enhanced base class for ViewComponent previews with additional features.
      #
      # Poetry::Core::Preview::Base extends the standard ViewComponent::Preview with several enhancements:
      # - Automatic component class inference from preview class name
      # - Template rendering support with custom layouts
      # - Container class configuration with inheritance
      # - Lookbook display parameters integration
      # - Convenient shortcut methods for rendering components
      #
      # @example Basic usage
      #   class ButtonPreview < Poetry::Core::Preview::Base
      #     # Automatically infers Button::Component, ButtonComponent, or Button
      #     def default
      #       render_component(text: "Click me", variant: :primary)
      #     end
      #
      #     def with_custom_container
      #       self.class.container_class = "p-4 bg-gray-100"
      #       render_component(text: "Styled container")
      #     end
      #   end
      #
      # @example Using render_with for template locals
      #   class CardPreview < Poetry::Core::Preview::Base
      #     def default
      #       render_with(title: "Card Title", description: "Card description")
      #     end
      #   end
      #
      # @example Passing a component instance directly
      #   class AlertPreview < Poetry::Core::Preview::Base
      #     def warning
      #       component = AlertComponent.new(type: :warning, dismissible: true)
      #       render_component(component)
      #     end
      #   end
      #
      # @example Accessing Lookbook theme
      #   class ThemeAwarePreview < Poetry::Core::Preview::Base
      #     def default
      #       theme = current_theme # Gets current Lookbook theme
      #       render_component(theme: theme)
      #     end
      #   end
      #
      class Base < ViewComponent::Preview
        self.abstract_class = true

        include Poetry::Core::Preview::Template

        DEFAULT_CONTAINER_CLASS = ""

        class << self
          # Ensures child preview classes inherit layout configuration.
          #
          # @param child [Class] the inheriting preview class
          # @return [void]
          # @api private
          def inherited(child)
            child.layout(@layout) if defined?(@layout)
            super
          end

          attr_writer :container_class, :component_class_name

          # Returns the configured container CSS class for the preview.
          #
          # Container classes are inherited from parent preview classes. If not explicitly set,
          # uses the parent's container class or DEFAULT_CONTAINER_CLASS.
          #
          # @return [String] the container CSS class
          # @example
          #   class MyPreview < Poetry::Core::Preview::Base
          #     self.container_class = "p-8 bg-white"
          #   end
          #
          #   MyPreview.container_class # => "p-8 bg-white"
          def container_class
            return @container_class if defined?(@container_class)

            @container_class =
              if superclass.respond_to?(:container_class)
                superclass.container_class
              else
                DEFAULT_CONTAINER_CLASS
              end
          end

          # Prepares render arguments by building component instance and setting container class.
          #
          # @return [Hash] render arguments with locals configured
          # @api private
          def render_args(...)
            super.tap do |res|
              res[:locals] ||= {}
              build_component_instance(res[:locals])
              res[:locals][:container_class] ||= container_class
            end
          end

          # Infers the component class name from the preview class name.
          #
          # Tries multiple naming conventions in order:
          # - Namespace::ButtonPreview => Namespace::Button::Component
          # - Namespace::ButtonPreview => Namespace::ButtonComponent
          # - Namespace::ButtonPreview => Namespace::Button
          # - Button::Preview => Button::Component | ButtonComponent | Button
          #
          # @return [String, nil] the inferred component class name or nil if not found
          # @example
          #   class MyApp::ButtonPreview < Poetry::Core::Preview::Base
          #   end
          #
          #   MyApp::ButtonPreview.component_class_name
          #   # => "MyApp::Button::Component" (if it exists)
          #   # or "MyApp::ButtonComponent" (if it exists)
          #   # or "MyApp::Button" (if it exists)
          def component_class_name
            @component_class_name ||= begin
              component_name = name.sub(/(::Preview|Preview)$/, "")
              [
                "#{component_name}::Component",
                "#{component_name}Component",
                component_name
              ].find(&:safe_constantize)
            end
          end

          private

          # Builds a component instance and adds it to locals.
          #
          # If component is already present in locals, returns unchanged.
          # If component class cannot be instantiated, sets error message in locals.
          #
          # @param locals [Hash] the locals hash to modify
          # @return [Hash] the modified locals hash
          # @api private
          def build_component_instance(locals)
            return locals unless locals[:component].nil?

            locals[:component] = component_class_name.safe_constantize&.new
          rescue StandardError => e
            locals[:component] = nil
            locals[:error] = e.message
          end
        end

        # Renders the preview with custom template locals.
        #
        # This is a convenience method that wraps render_with_template, making it easier
        # to pass locals to your preview templates.
        #
        # @param locals [Hash] key-value pairs to pass as local variables to the template
        # @return [String] the rendered template
        # @example
        #   def default
        #     render_with(title: "Hello", message: "World")
        #   end
        # Renders a NESTED component inside a slot/content block. Plain
        # render() there resolves to the preview DSL's own render (a
        # declaration returning a hash) and the nested component silently
        # vanishes - button icons, card actions, dialog footer buttons were
        # all missing from every preview until the N2 a11y rig caught it.
        def embed(component, &block)
          ApplicationController.new.view_context.render(component, &block)
        end

        def render_with(**locals)

          render_with_template(locals: locals)
        end

        # Renders a component instance or creates one from props.
        #
        # This method provides a convenient way to render components in previews. It can accept
        # either a component instance directly, or a hash of props to instantiate the component.
        # The component class is automatically inferred from the preview class name.
        #
        # @param component_or_props [ViewComponent::Base, Hash, nil] either a component instance
        #   or a hash of props to pass to the component constructor
        # @param block [Proc, nil] optional block to pass as content to the component
        # @return [String] the rendered component
        # @example With props hash
        #   def default
        #     render_component(variant: :primary, text: "Click me")
        #   end
        #
        # @example With component instance
        #   def custom
        #     component = ButtonComponent.new(variant: :primary)
        #     render_component(component)
        #   end
        #
        # @example With content block
        #   def with_content
        #     render_component(variant: :primary) do
        #       "Custom content"
        #     end
        #   end
        def render_component(component_or_props = nil, &block)
          component = if component_or_props.is_a?(::ViewComponent::Base)
                        component_or_props
                      else
                        self.class.component_class_name.constantize.new(**(component_or_props || {}))
                      end

          render_with(component: component, content_block: block)
        end

        # Retrieves Lookbook display parameters from the current request.
        #
        # This method accesses display parameters set by Lookbook (such as theme, viewport, etc.)
        # by accessing the controller from the request store or thread local storage.
        #
        # @return [Hash] the Lookbook display parameters, or empty hash if not available
        # @example
        #   def default
        #     params = lookbook_display_params
        #     # => { theme: "dark", viewport: "mobile" }
        #   end
        def lookbook_display_params
          # Try to get the controller from Rails request store
          if defined?(RequestStore) && RequestStore.store[:controller]
            RequestStore.store[:controller].params.dig(:lookbook, :display) || {}
          elsif Thread.current[:__view_component_preview_controller__]
            Thread.current[:__view_component_preview_controller__].params.dig(:lookbook, :display) || {}
          else
            {}
          end
        end

        # Returns the current Lookbook theme.
        #
        # This is a convenience wrapper around lookbook_display_params that specifically
        # retrieves the theme parameter, useful for creating theme-aware preview examples.
        #
        # @return [String, nil] the current theme name, or nil if not set
        # @example
        #   def default
        #     case current_theme
        #     when "dark"
        #       render_component(bg_color: "bg-gray-900")
        #     when "light"
        #       render_component(bg_color: "bg-white")
        #     else
        #       render_component
        #     end
        #   end
        def current_theme
          lookbook_display_params[:theme]
        end
      end
    end
  end
end
