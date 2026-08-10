# frozen_string_literal: true

module Poetry
  module Ui
    module Tooltip
      # The Tooltip preview matrix: the shadcn tooltip-demo composition,
      # the provider warm row (one scope, three controls), the label:
      # announcement override, a placement sample, the Radix opt-back
      # delay, and the server-pinned open state.
      class Preview < Poetry::Core::Preview::Base
        # The tooltip-demo port: outline Button trigger, plain text hint.
        def default
          render_component do |tooltip|
            tooltip.with_trigger(variant: :outline) { "Hover" }
            "Add to library"
          end
        end

        # ONE provider scope: the first open is delayed, sweeping along
        # the row is instant (the warm grace), cold again 300ms after
        # leaving - wrap toolbar rows exactly like this.
        def provider_row
          render_with_template
        end

        # Rich visual content with label: - the announced body is the
        # plain-text label; the visual children stay (the kbd recipe).
        def with_label
          render_component(label: "Command S saves the document") do |tooltip|
            tooltip.with_trigger(variant: :outline, label: "Save shortcut") { "Save" }
            "Saves the document <kbd>⌘S</kbd>".html_safe
          end
        end

        # Server-pinned open (controllable-state; the controller
        # reconciles describedby + the layer on connect).
        def open
          render_component(open: true) do |tooltip|
            tooltip.with_trigger(variant: :outline) { "Pinned" }
            "Server-rendered open"
          end
        end

        # Placement sample (Radix Tooltip defaults side: :top - the trio's
        # odd one out; the arrow follows the resolved side).
        def side_bottom
          render_component(side: :bottom, align: :start) do |tooltip|
            tooltip.with_trigger(variant: :outline) { "Below" }
            "side: :bottom, align: :start"
          end
        end

        # The Radix opt-back for hint-dense screens: shadcn's provider
        # default is 0ms; 700ms is the recommended delay when a page is
        # dense with tooltips.
        def delayed
          render_component(delay_duration: 700) do |tooltip|
            tooltip.with_trigger(variant: :outline) { "Patient hover" }
            "Opens after 700ms"
          end
        end

        # disable_hoverable_content: true - pointing at the card itself
        # never holds it open (the strict hover mode).
        def not_hoverable
          render_component(disable_hoverable_content: true) do |tooltip|
            tooltip.with_trigger(variant: :outline) { "Hover" }
            "Closes the moment you leave the trigger"
          end
        end
      end
    end
  end
end
