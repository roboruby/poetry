# frozen_string_literal: true

module Poetry
  module Ui
    # Pressed-state buttons.
    module Toggle
      # A pressed-state button: aria-pressed plus a bare data-pressed
      # presence attribute on a plain <button> - the standard ARIA
      # toggle-button pattern. Pressed state is UI state
      # (bold-in-a-toolbar, bookmark-on), so a Toggle carries no form
      # machinery: state that must submit with a form is a Checkbox, an
      # instant on/off setting is a Switch, and exclusive or grouped sets
      # are a ToggleGroup.
      #
      # Icon-only toggles require label:, and the label must not change
      # with state ("Bookmark", never "Remove bookmark") - aria-pressed
      # already carries the state.
      #
      # @example An icon-only bookmark toggle
      #   render Poetry::Ui::Toggle::Component.new(label: "Bookmark", pressed: bookmarked?) do
      #     poetry_icon(name: :bookmark)
      #   end
      class Component < Poetry::Core::Component
        # The closed vocabulary for the variant axis.
        VARIANTS = %i[default outline].freeze
        # The closed vocabulary for the size axis.
        SIZES = %i[default sm lg].freeze

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Use poetry_toggle - never a Button with hand-managed aria-pressed.",
          "Toggle is UI state, NOT form data: never try to submit it. Form value -> Checkbox; instant " \
          "setting -> Switch; exclusive/grouped -> ToggleGroup.",
          "Icon-only toggles MUST pass label:, and the label must NOT change with state ('Bookmark', " \
          "never 'Remove bookmark').",
          "aria-pressed is the vocabulary - never aria-checked or aria-expanded on a Toggle.",
          "Wire the EFFECT to poetry:toggle:change (or click) and revert via set(false) on failure - " \
          "a pressed toggle whose effect failed is a lie.",
          "Pressed visual is accent - don't override data-pressed colors per-instance (theme-level only)."
        ].freeze

        # Click flips aria-pressed and data-pressed together; the DOM is
        # the store (no Values). No keydown wiring - Space and Enter
        # already activate a native button.
        use_stimulus do
          on :root do
            controller :pressed do
              register
              action :toggle, on: :click
            end
          end
        end

        # The visual treatment; :outline adds a border for standalone use.
        style :variant, default: :default, required: true, variants: VARIANTS
        # The control's size axis.
        style :size, default: :default, required: true, variants: SIZES

        # The server-rendered pressed state.
        option :pressed, :boolean, default: false
        # Disables the control and forwards to the native button.
        option :disabled, :boolean, default: false
        # REQUIRED when icon-only; must be state-INVARIANT (APG: aria-pressed
        # carries the state - a flipping name makes SRs announce nonsense).
        option :label, :string

        part "toggle", "The pressed-state <button> - the whole component; aria-pressed carries the " \
                       "state and the controller flips both together",
             states: {
               "data-pressed" => "pressed (bare presence boolean - absent when unpressed, never " \
                                 "data-pressed=false)",
               "data-disabled" => "disabled (rendered alongside native disabled for styling-hook parity)",
               "data-variant" => { condition: "the visual variant", values: VARIANTS.map(&:to_s) },
               "data-size" => { condition: "the size", values: SIZES.map(&:to_s) }
             }

        # An icon-only (or empty) toggle without an accessible name never
        # ships.
        # @api private
        def before_render
          return if label.present? || visible_text?

          raise ArgumentError,
                "icon-only Toggle requires label: (the accessible name, state-invariant - " \
                "'Bookmark', never 'Remove bookmark')"
        end

        # @api private
        def call
          content_tag(:button, content, **root_attributes.to_attributes)
        end

        # @api private
        def root_attributes
          attrs = {
            "type" => "button", "data-slot" => "toggle",
            "aria-pressed" => pressed.to_s,
            "data-variant" => variant, "data-size" => size,
            "disabled" => disabled
          }
          # Pressed is a bare presence attribute: data-pressed when on,
          # absent when off (never data-pressed=false).
          attrs["data-pressed"] = "" if pressed
          # data-disabled renders alongside native disabled - kept for
          # styling-hook parity (and the group-context roving filter).
          attrs["data-disabled"] = "" if disabled
          attrs["aria-label"] = label if label.present?
          html_attributes.merge_if_not_set(
            attrs.merge(stimulus_attributes_for(:root)).merge(component_data_attributes)
          )
        end

        private

        def visible_text?
          content? && content.to_s.gsub(/<[^>]+>/, " ").strip.present?
        end
      end
    end
  end
end
