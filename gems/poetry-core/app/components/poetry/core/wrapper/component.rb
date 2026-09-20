# frozen_string_literal: true

module Poetry
  module Core
    # Namespace of the conditional wrapper: {Wrapper::Component} renders
    # outer HTML around a child component only when the child itself
    # renders.
    module Wrapper
      # Wraps any component with custom HTML.
      # The whole wrapper is only rendered when the child component's #render? returns true,
      # so it can conditionally render the outer HTML for a component without
      # conditionals in templates.
      #
      # Adapted from an MIT-licensed source (source and license in
      # THIRD_PARTY_NOTICES.md).
      #
      # The child's render? is consulted before the child gains a view
      # context: a render? that calls view helpers works standalone but
      # not under the wrapper.
      #
      # @example
      #   render Poetry::Core::Wrapper::Component.new(badge) do |wrapper|
      #     tag.div(class: "mt-2") { wrapper.component }
      #   end
      class Component < ViewComponent::Base
        # Raised when the block calls #component more than once - each
        # wrapper renders its child exactly one time.
        class DoubleRenderError < Poetry::Core::Error
          # Names the child in the message.
          #
          # @param component [ViewComponent::Base] the child rendered twice
          def initialize(component)
            super("A child component could only be rendered once within a wrapper: #{component}")
          end
        end

        # Raised when the wrapper's block never rendered the child - the
        # wrap would silently drop it.
        class UnrenderedChildError < Poetry::Core::Error
          # Names the dropped child in the message.
          #
          # @param component [ViewComponent::Base] the child the block skipped
          def initialize(component)
            super("The block never rendered the wrapped child - call #component where it belongs: #{component}")
          end
        end

        attr_reader :component_instance

        delegate :render?, to: :component_instance

        # Wraps a single child component; intentionally does not chain to
        # ViewComponent::Base#initialize (it only needs the child reference).
        #
        # @param component [ViewComponent::Base] the child component to wrap
        def initialize(component) # rubocop:disable Lint/MissingSuper
          raise ArgumentError, "Wrapper wraps a component instance (got nil)" if component.nil?

          @component_instance = component
        end

        # Returns the block's output, which must have rendered the child -
        # a block that skips {#component} would drop the child silently,
        # so it teaches instead. (An alias couldn't be used here:
        # ViewComponent checks method presence when choosing between
        # #call and a template.)
        #
        # @return [ActiveSupport::SafeBuffer, nil] the block's output
        # @raise [UnrenderedChildError] when the block never called {#component}
        def call
          content.tap do
            raise UnrenderedChildError, component_instance unless @rendered
          end
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
