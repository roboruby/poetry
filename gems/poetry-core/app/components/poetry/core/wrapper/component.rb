# frozen_string_literal: true

module Poetry
  module Core
    # Namespace of the conditional-wrapper component.
    module Wrapper
      # Wraps any component with custom HTML.
      # The whole wrapper is only rendered when the child component's #render? returns true,
      # so it can conditionally render the outer HTML for a component without
      # conditionals in templates.
      #
      # @example
      #   render Poetry::Core::Wrapper::Component.new(badge) do |wrapper|
      #     tag.div(class: "mt-2") { wrapper.component }
      #   end
      class Component < ViewComponent::Base
        # Raised when the block calls #component more than once - each
        # wrapper renders its child exactly one time.
        class DoubleRenderError < StandardError
          def initialize(component)
            super("A child component could only be rendered once within a wrapper: #{component}")
          end
        end

        attr_reader :component_instance

        delegate :render?, to: :component_instance

        # Wraps a single child component; intentionally does not chain to
        # ViewComponent::Base#initialize (it only needs the child reference).
        def initialize(component) # rubocop:disable Lint/MissingSuper
          @component_instance = component
        end

        # Simply return the contents of the block passed to #render_component.
        # (Alias couldn't be used here 'cause ViewComponent check for the method presence when
        # choosing between #call and a template.)
        def call
          content
        end

        # Returns the rendered child component.
        # The name is chosen for convenient usage in templates,
        # so `= wrapper.component` reads naturally at the spot where the
        # child belongs.
        #
        # @return [ActiveSupport::SafeBuffer] the rendered child HTML
        def component
          raise DoubleRenderError, component_instance if @rendered

          @rendered = component_instance.render_in(view_context).html_safe
        end
      end
    end
  end
end
