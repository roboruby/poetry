# frozen_string_literal: true

module Poetry
  module Ui
    module Toolbar
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(label: "Text formatting") do |toolbar|
            toolbar.with_button(variant: :ghost, size: :sm) { "Bold" }
            toolbar.with_button(variant: :ghost, size: :sm) { "Italic" }
            toolbar.with_separator
            toolbar.with_button(variant: :ghost, size: :sm) { "Link" }
          end
        end

        # The table bulk-action strip: actions, a seam, then the filter
        # input - the roving caret guard keeps the input's arrow keys.
        def bulk_actions_with_filter
          render_component(label: "Invoice actions") do |toolbar|
            toolbar.with_button(variant: :outline, size: :sm) { "Export" }
            toolbar.with_button(variant: :outline, size: :sm, disabled: true) { "Archive" }
            toolbar.with_separator
            toolbar.with_input(type: "search", placeholder: "Filter invoices…",
                               "aria-label": "Filter invoices")
          end
        end

        def vertical
          render_component(label: "Canvas tools", orientation: :vertical) do |toolbar|
            toolbar.with_button(variant: :ghost, size: :sm) { "Select" }
            toolbar.with_button(variant: :ghost, size: :sm) { "Draw" }
            toolbar.with_separator
            toolbar.with_button(variant: :ghost, size: :sm) { "Erase" }
          end
        end
      end
    end
  end
end
