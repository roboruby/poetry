# frozen_string_literal: true

module Poetry
  module Ui
    module Select
      # The Select preview matrix: the ported select-demo composition, the
      # scrollable grouped list (scroll-button case), placeholder vs
      # valued, both trigger sizes, disabled, invalid (the Field
      # aria-invalid chain), RTL, and the server-rendered open state.
      class Preview < Poetry::Core::Preview::Base
        # The select-demo port: grouped fruit, placeholder shown until a
        # commit writes the native select + the value display together.
        def default
          render_component(placeholder: "Select a fruit", "aria-label": "Fruit") do |select|
            select.with_group(label: "Fruits") do |group|
              group.with_item(value: "apple") { "Apple" }
              group.with_item(value: "banana") { "Banana" }
              group.with_item(value: "blueberry") { "Blueberry" }
              group.with_item(value: "grapes", disabled: true) { "Grapes" }
              group.with_item(value: "pineapple") { "Pineapple" }
            end
          end
        end

        # select-scrollable parity: grouped timezones behind max-h - the
        # scroll buttons appear per-direction at the extremes.
        def scrollable
          render_component(placeholder: "Select a timezone", "aria-label": "Timezone") do |select|
            select.with_group(label: "North America") do |group|
              group.with_item(value: "est") { "Eastern Standard Time (EST)" }
              group.with_item(value: "cst") { "Central Standard Time (CST)" }
              group.with_item(value: "mst") { "Mountain Standard Time (MST)" }
              group.with_item(value: "pst") { "Pacific Standard Time (PST)" }
            end
            select.with_separator
            select.with_group(label: "Europe & Africa") do |group|
              group.with_item(value: "gmt") { "Greenwich Mean Time (GMT)" }
              group.with_item(value: "cet") { "Central European Time (CET)" }
              group.with_item(value: "eet") { "Eastern European Time (EET)" }
              group.with_item(value: "west") { "Western European Summer Time (WEST)" }
            end
            select.with_separator
            select.with_group(label: "Asia") do |group|
              group.with_item(value: "ist") { "India Standard Time (IST)" }
              group.with_item(value: "cst_china") { "China Standard Time (CST)" }
              group.with_item(value: "jst") { "Japan Standard Time (JST)" }
            end
          end
        end

        # The server-rendered value: display label + native option selected
        # + aria-selected/data-selected on the option, all in one pass.
        def valued
          render_component(value: "banana", placeholder: "Select a fruit", "aria-label": "Fruit") do |select|
            select.with_item(value: "apple") { "Apple" }
            select.with_item(value: "banana") { "Banana" }
            select.with_item(value: "blueberry") { "Blueberry" }
          end
        end

        # data-size=sm - h-8, matching Input's dense form rows.
        def small
          render_component(size: :sm, placeholder: "Per page", "aria-label": "Per page") do |select|
            select.with_item(value: "10") { "10" }
            select.with_item(value: "25") { "25" }
            select.with_item(value: "50") { "50" }
          end
        end

        # Disables the trigger AND the native select together.
        def disabled
          render_component(disabled: true, placeholder: "Select a fruit", "aria-label": "Fruit") do |select|
            select.with_item(value: "apple") { "Apple" }
            select.with_item(value: "banana") { "Banana" }
          end
        end

        # The Field error chain lands aria-invalid on the trigger - the
        # source aria-invalid: classes fire with zero Select-side code.
        def invalid
          render_component(placeholder: "Choose department", required: true,
                           "aria-label": "Department", "aria-invalid": "true") do |select|
            select.with_item(value: "eng") { "Engineering" }
            select.with_item(value: "design") { "Design" }
          end
        end

        # dir=rtl flips popper alignment via the direction helper; the
        # listbox itself is flat (Left/Right stay no-ops).
        def rtl
          render_component(dir: :rtl, value: "ar", "aria-label": "اللغة") do |select|
            select.with_item(value: "ar") { "العربية" }
            select.with_item(value: "he") { "עברית" }
          end
        end

        # Server-rendered open state (controllable-state: the attributes
        # are the store; the controller reconciles on connect).
        def open
          render_component(open: true, value: "apple", placeholder: "Select a fruit",
                           "aria-label": "Fruit") do |select|
            select.with_group(label: "Fruits") do |group|
              group.with_item(value: "apple") { "Apple" }
              group.with_item(value: "banana") { "Banana" }
            end
            select.with_separator
            select.with_item(value: "other") { "Other" }
          end
        end
      end
    end
  end
end
