# frozen_string_literal: true

module Poetry
  module Ui
    module Combobox
      # The Combobox preview matrix: the ported combobox-demo composition
      # (framework picker), placeholder vs valued, grouped options, the
      # server-rendered open state, disabled trigger/options, the
      # filter:false server mode, RTL, and the width knob.
      class Preview < Poetry::Core::Preview::Base
        FRAMEWORKS = [%w[next.js Next.js], %w[sveltekit SvelteKit], %w[nuxt.js Nuxt.js],
                      %w[remix Remix], %w[astro Astro]].freeze

        # The combobox-demo port: click (or type on) the trigger to open a
        # typing session; the filter narrows, Enter commits to the hidden
        # native select, Esc/Tab leave the value untouched.
        def default
          render_component(name: "framework", placeholder: "Select framework...",
                           search_placeholder: "Search framework...", "aria-label": "Framework") do |combobox|
            FRAMEWORKS.each { |value, label| combobox.with_item(value: value) { label } }
          end
        end

        # The server-rendered value: display label + native option selected
        # + the aria-selected/data-selected twin + the visible check indicator,
        # all in one pass.
        def valued
          render_component(name: "framework", value: "sveltekit", placeholder: "Select framework...",
                           search_placeholder: "Search framework...", "aria-label": "Framework") do |combobox|
            FRAMEWORKS.each { |value, label| combobox.with_item(value: value) { label } }
          end
        end

        # show_clear (the source's showClear): the trigger-side deselection X
        # swaps in over the chevrons while a value is committed - the
        # golden pins the swap (X visible, chevron box kept but invisible).
        def clear
          render_component(name: "framework", value: "next.js", show_clear: true,
                           placeholder: "Select framework...", search_placeholder: "Search framework...",
                           "aria-label": "Framework") do |combobox|
            FRAMEWORKS.each { |value, label| combobox.with_item(value: value) { label } }
          end
        end

        # Groups keep Command's heading anatomy; the filter hides a group
        # when all its options hide.
        def grouped
          render_component(name: "stack", placeholder: "Select a tool...",
                           search_placeholder: "Search tools...", "aria-label": "Tool") do |combobox|
            combobox.with_group(heading: "Frameworks") do |group|
              group.with_item(value: "rails") { "Ruby on Rails" }
              group.with_item(value: "hanami") { "Hanami" }
            end
            combobox.with_separator
            combobox.with_group(heading: "Test runners") do |group|
              group.with_item(value: "minitest") { "Minitest" }
              group.with_item(value: "rspec") { "RSpec" }
            end
          end
        end

        # Server-rendered open state (controllable-state: the attributes
        # are the store; the controller reconciles on connect). Type a
        # non-matching query ("zzz") for the zero-match state: every option
        # hides, the empty part shows, the popup STAYS OPEN.
        def open
          render_component(name: "framework", open: true, value: "remix",
                           placeholder: "Select framework...", search_placeholder: "Search framework...",
                           "aria-label": "Framework") do |combobox|
            combobox.with_empty { "No framework found." }
            FRAMEWORKS.each { |value, label| combobox.with_item(value: value) { label } }
          end
        end

        # Disables the trigger AND the native select together.
        def disabled
          render_component(name: "framework", disabled: true, placeholder: "Select framework...",
                           "aria-label": "Framework") do |combobox|
            FRAMEWORKS.each { |value, label| combobox.with_item(value: value) { label } }
          end
        end

        # Disabled options: skipped by arrows and the filter re-seat;
        # commit is unreachable (the engine's collection filter).
        def disabled_options
          render_component(name: "plan", placeholder: "Select a plan...",
                           "aria-label": "Plan") do |combobox|
            combobox.with_item(value: "hobby") { "Hobby" }
            combobox.with_item(value: "pro") { "Pro" }
            combobox.with_item(value: "enterprise", disabled: true) { "Enterprise (contact sales)" }
          end
        end

        # filter: false - the SERVER-DRIVEN mode: typing never hides
        # options client-side; the host re-renders the list (the Turbo
        # frame ?q= recipe) and the frame response must render the twin
        # native <option> for every committable item (the recipe's one
        # hard rule).
        def server_mode
          render_component(name: "author_id", filter: false, placeholder: "Search authors...",
                           search_placeholder: "Type to search...", "aria-label": "Author") do |combobox|
            combobox.with_item(value: "1") { "Ada Lovelace" }
            combobox.with_item(value: "2") { "Grace Hopper" }
            combobox.with_item(value: "3") { "Annie Easley" }
          end
        end

        # dir=rtl: the indicator's ms-auto keeps the check on the reading-
        # order end (the logical-property fix over the demo's ml-auto);
        # popper alignment flips via the direction helper.
        def rtl
          render_component(name: "language", dir: :rtl, value: "ar", "aria-label": "اللغة") do |combobox|
            combobox.with_item(value: "ar") { "العربية" }
            combobox.with_item(value: "he") { "עברית" }
          end
        end

        # The width knob: one utility on the trigger; the popup ALWAYS
        # tracks it via the anchor-width binding.
        def wide
          render_component(name: "timezone", width: "w-80", placeholder: "Select a timezone...",
                           search_placeholder: "Search timezones...", "aria-label": "Timezone") do |combobox|
            combobox.with_item(value: "est") { "Eastern Standard Time (EST)" }
            combobox.with_item(value: "cet") { "Central European Time (CET)" }
            combobox.with_item(value: "jst") { "Japan Standard Time (JST)" }
          end
        end

        # ## Multiple

        # multiple: true - the chips FIELD replaces the trigger (the source's
        # input-inside layout): value: takes an array, one chip per
        # committed value in value order, the filter input rides inline,
        # selection TOGGLES with the popup staying open, and the native
        # <select multiple> posts frameworks[].
        def multiple
          render_component(name: "frameworks", multiple: true, value: %w[sveltekit remix],
                           placeholder: "Select frameworks...", "aria-label": "Frameworks") do |combobox|
            FRAMEWORKS.each { |value, label| combobox.with_item(value: value) { label } }
          end
        end

        # Empty selection: no toolbar role, data-placeholder on the frame,
        # the placeholder text riding the inline input.
        def multiple_empty
          render_component(name: "frameworks", multiple: true,
                           placeholder: "Select frameworks...", "aria-label": "Frameworks") do |combobox|
            FRAMEWORKS.each { |value, label| combobox.with_item(value: value) { label } }
          end
        end

        # Disabled: the frame dims (data-disabled), chips carry
        # data-disabled (focus is blocked entirely), the input and native
        # select disable together.
        def multiple_disabled
          render_component(name: "frameworks", multiple: true, disabled: true, value: %w[astro],
                           placeholder: "Select frameworks...", "aria-label": "Frameworks") do |combobox|
            FRAMEWORKS.each { |value, label| combobox.with_item(value: value) { label } }
          end
        end
      end
    end
  end
end
