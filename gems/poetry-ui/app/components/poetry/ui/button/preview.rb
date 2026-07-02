# frozen_string_literal: true

module Poetry
  module Ui
    module Button
      # The Button preview matrix - one corpus, three uses: Lookbook docs,
      # test fixtures (smoke-rendered in CI), and the agent visual loop.
      class Preview < Poetry::Core::Preview::Base
        # @!group Variants

        def default
          render_component(variant: :default) { "Save changes" }
        end

        def destructive
          render_component(variant: :destructive) { "Delete account" }
        end

        def outline
          render_component(variant: :outline) { "Cancel" }
        end

        def secondary
          render_component(variant: :secondary) { "Duplicate" }
        end

        def ghost
          render_component(variant: :ghost) { "Dismiss" }
        end

        def link
          render_component(variant: :link) { "Learn more" }
        end

        # @!endgroup

        # @!group Sizes

        def size_xs
          render_component(size: :xs) { "Tag" }
        end

        def size_sm
          render_component(size: :sm) { "Small" }
        end

        def size_lg
          render_component(size: :lg) { "Continue" }
        end

        def icon_only
          render_component(size: :icon, label: "Add item") do |component|
            component.with_leading { embed(Icon::Component.new(name: :plus)) }
          end
        end

        # @!endgroup

        # @!group States

        def disabled
          render_component(disabled: true) { "Unavailable" }
        end

        def loading
          render_component(loading: true) { "Saving" }
        end

        # @!endgroup

        # @!group Composition

        def with_icons
          render_component(variant: :destructive) do |component|
            component.with_leading { embed(Icon::Component.new(name: :trash)) }
            "Delete"
          end
        end

        def as_link
          render_component(tag: :a, href: "#", variant: :outline) { "View pricing" }
        end

        # @!endgroup
      end
    end
  end
end
