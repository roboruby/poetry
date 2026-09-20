# frozen_string_literal: true

module Poetry
  module Ui
    module Toggle
      # The Toggle preview matrix: 2 variants x 3 sizes x pressed states,
      # icon-only (label enforced) and icon+text - the toggle-demo corpus.
      class Preview < Poetry::Core::Preview::Base
        # @!group Variants

        # The toggle-demo port: icon-only bookmark with a state-invariant
        # accessible name.
        def default
          render_component(label: "Bookmark") do |_component|
            embed(Icon::Component.new(name: :bookmark))
          end
        end

        def outline
          render_component(variant: :outline, label: "Italic") do |_component|
            embed(Icon::Component.new(name: :italic))
          end
        end

        # @!endgroup

        # @!group States

        def pressed
          render_component(pressed: true, label: "Bold") do |_component|
            embed(Icon::Component.new(name: :bold))
          end
        end

        def disabled
          render_component(disabled: true, variant: :outline, label: "Underline") do |_component|
            embed(Icon::Component.new(name: :underline))
          end
        end

        def disabled_pressed
          render_component(disabled: true, pressed: true, label: "Bold") do |_component|
            embed(Icon::Component.new(name: :bold))
          end
        end

        # @!endgroup

        # @!group Sizes

        def small
          render_component(size: :sm, variant: :outline, label: "Italic") do |_component|
            embed(Icon::Component.new(name: :italic))
          end
        end

        def large
          render_component(size: :lg, label: "Bold") do |_component|
            embed(Icon::Component.new(name: :bold))
          end
        end

        # @!endgroup

        # @!group Composition

        # toggle-with-text: the visible text IS the accessible name - no
        # label: needed.
        def with_text
          render_component(variant: :outline) do |_component|
            embed(Icon::Component.new(name: :italic)).concat("Italic")
          end
        end

        # @!endgroup
      end
    end
  end
end
