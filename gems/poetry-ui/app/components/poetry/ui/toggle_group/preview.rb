# frozen_string_literal: true

module Poetry
  module Ui
    module ToggleGroup
      # The ToggleGroup preview matrix: both types x both variants x both
      # spacing modes with mixed item states - the toggle-group-demo corpus
      # plus the segmented picker and the disabled-item edge.
      class Preview < Poetry::Core::Preview::Base
        # @!group Types

        # The toggle-group-demo port: MULTIPLE + outline, icon items each
        # with a state-invariant aria-label (toolbar semantics).
        def default
          render_component(type: :multiple, variant: :outline, values: %w[bold],
                           label: "Text formatting") do |group|
            formatting_items(group)
          end
        end

        # single = a radio group that can deselect to empty: role=radiogroup,
        # items role=radio + aria-checked (aria-pressed stripped).
        def single
          render_component(type: :single, value: "center", label: "Text alignment") do |group|
            alignment_items(group)
          end
        end

        # @!endgroup

        # @!group Variants

        # The classic segmented control: single + outline + spacing 0
        # (joined corners, collapsed borders, focus ring painting over).
        def segmented
          render_component(type: :single, variant: :outline, value: "list", spacing: 0,
                           label: "View") do |group|
            group.with_item(value: "list", label: "List view") { embed(Icon::Component.new(name: :list)) }
            group.with_item(value: "grid", label: "Grid view") { embed(Icon::Component.new(name: :"layout-grid")) }
          end
        end

        # spacing > 0: free-standing toggles with a gap (each keeps its own
        # rounded corners + shadow).
        def spaced
          render_component(type: :multiple, variant: :outline, spacing: 2, values: %w[bold italic],
                           label: "Text formatting") do |group|
            formatting_items(group)
          end
        end

        # orientation: :vertical - the column layout (data-vertical flips
        # the root; segment chains and radii are orientation-guarded).
        def vertical
          render_component(type: :multiple, orientation: :vertical, spacing: 1,
                           values: %w[bold italic], label: "Text formatting") do |group|
            formatting_items(group)
          end
        end

        # The vertical SEGMENTED control: the orientation-guarded border/
        # radius chain (border-t collapse, first rounded-t / last rounded-b).
        def vertical_segmented
          render_component(type: :single, variant: :outline, orientation: :vertical, spacing: 0,
                           value: "list", label: "View") do |group|
            group.with_item(value: "list", label: "List view") { embed(Icon::Component.new(name: :list)) }
            group.with_item(value: "grid", label: "Grid view") { embed(Icon::Component.new(name: :"layout-grid")) }
          end
        end

        # @!endgroup

        # @!group Sizes

        def small
          render_component(type: :multiple, size: :sm, variant: :outline, label: "Text formatting") do |group|
            formatting_items(group)
          end
        end

        def large
          render_component(type: :multiple, size: :lg, label: "Text formatting") do |group|
            formatting_items(group)
          end
        end

        # @!endgroup

        # @!group States

        # A disabled item mid-group: skipped by Tab AND filtered from the
        # roving collection; the segment borders still join.
        def disabled_item
          render_component(type: :single, variant: :outline, value: "left",
                           label: "Text alignment") do |group|
            group.with_item(value: "left", label: "Align left") { embed(Icon::Component.new(name: :"text-align-start")) }
            group.with_item(value: "center", label: "Align center", disabled: true) do
              embed(Icon::Component.new(name: :"text-align-center"))
            end
            group.with_item(value: "right", label: "Align right") { embed(Icon::Component.new(name: :"text-align-end")) }
          end
        end

        def disabled_group
          render_component(type: :multiple, variant: :outline, disabled: true,
                           label: "Text formatting") do |group|
            formatting_items(group)
          end
        end

        # @!endgroup

        # @!group Composition

        # Icon + text items (the caller's content block, Toggle-style).
        def with_text
          render_component(type: :single, variant: :outline, value: "preview", label: "Mode") do |group|
            group.with_item(value: "code") { embed(Icon::Component.new(name: :bold)).concat("Code") }
            group.with_item(value: "preview") { "Preview" }
          end
        end

        # @!endgroup

        private

        def formatting_items(group)
          group.with_item(value: "bold", label: "Toggle bold") { embed(Icon::Component.new(name: :bold)) }
          group.with_item(value: "italic", label: "Toggle italic") { embed(Icon::Component.new(name: :italic)) }
          group.with_item(value: "underline", label: "Toggle underline") do
            embed(Icon::Component.new(name: :underline))
          end
        end

        def alignment_items(group)
          group.with_item(value: "left", label: "Align left") { embed(Icon::Component.new(name: :"text-align-start")) }
          group.with_item(value: "center", label: "Align center") { embed(Icon::Component.new(name: :"text-align-center")) }
          group.with_item(value: "right", label: "Align right") { embed(Icon::Component.new(name: :"text-align-end")) }
        end
      end
    end
  end
end
