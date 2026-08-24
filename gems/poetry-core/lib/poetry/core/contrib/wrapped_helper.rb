# frozen_string_literal: true

module Poetry
  module Core
    # Opt-in helper mixins shipped alongside the core (wrapping, translations).
    module Contrib
      # Provides a convenient method to wrap components with custom HTML code.
      #
      # This module adds the `#wrapped` method to components, allowing them to be
      # easily wrapped with a {Poetry::Core::Wrapper::Component}. The wrapper component
      # enables adding custom HTML around a component without modifying the
      # component itself, and respects the component's `render?` conditional logic.
      #
      # @example Basic usage
      #   class MyComponent < Poetry::Core::Component
      #     # WrappedHelper is already included via Poetry::Core::Component
      #   end
      #
      #   # In a view or template
      #   component = MyComponent.new(title: "Hello")
      #   wrapper = component.wrapped
      #
      # @example Using in a view template with custom wrapper HTML
      #   <%# app/components/my_component/component.html.erb %>
      #   <% component = MyComponent.new(title: "Hello") %>
      #   <%= render component.wrapped do |wrapper| %>
      #     <div class="custom-wrapper">
      #       <h2>Wrapped Content:</h2>
      #       <%= wrapper.component %>
      #     </div>
      #   <% end %>
      #
      # @example Conditional rendering
      #   # The wrapper only renders if the wrapped component's render? returns true
      #   class ConditionalComponent < Poetry::Core::Component
      #     def render?
      #       @show_content
      #     end
      #   end
      #
      #   # If @show_content is false, neither the wrapper nor component will render
      #   <%= render component.wrapped do |wrapper| %>
      #     <div class="wrapper"><%= wrapper.component %></div>
      #   <% end %>
      #
      # @see Poetry::Core::Wrapper::Component
      module WrappedHelper
        # Wraps the current component instance in a {Poetry::Core::Wrapper::Component}.
        #
        # This creates a wrapper that can be rendered with custom HTML surrounding
        # the component. The wrapper respects the wrapped component's `render?`
        # method, only rendering if it returns true.
        #
        # @return [Poetry::Core::Wrapper::Component] a wrapper component containing self
        #
        # @example
        #   component = MyComponent.new
        #   wrapper = component.wrapped
        #   wrapper.component_instance # => the original component
        def wrapped
          Poetry::Core::Wrapper::Component.new(self)
        end
      end
    end
  end
end
