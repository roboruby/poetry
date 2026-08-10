# frozen_string_literal: true

module Poetry
  module Ui
    module Toggle
      # Third of the toggle family (Toggle) - and the
      # family member that is NOT a form control. A Toggle is a styled
      # pressed-state button: aria-pressed + the bare data-pressed presence
      # boolean (Base UI vocabulary; unpressed = attribute absent) on a plain
      # <button> (no ARIA role - that IS the APG toggle-button pattern),
      # and NO hidden input, NO name:/value:, NO FormBuilder mapping -
      # explicit, Radix-exact (its Toggle carries zero form machinery).
      # Pressed state is UI state (bold-in-a-toolbar, bookmark-on); if the
      # state must submit with a form that's a Checkbox, an instant on/off
      # setting is a Switch, exclusive/grouped sets are ToggleGroup.
      #
      # Machinery: the poetry--core--pressed micro-controller (the smallest
      # in the suite) - deliberately separate from poetry--core--checked
      # (different ARIA vocabulary, no input to sync). The exported
      # `toggleVariants` cva ports as the shared Toggle::Style dictionary
      # (+ the VARIANTS/SIZES constants) that ToggleGroup items consume.
      class Component < Poetry::Core::Component
        VARIANTS = %i[default outline].freeze
        SIZES = %i[default sm lg].freeze

        # The aria-pressed vocabulary owner: flip + mirror data-pressed,
        # written together; the DOM is the store (no Values). No keydown
        # code - Space AND Enter activate a native button (Radix-exact).
        use_stimulus do
          on :root do
            controller :pressed do
              register
              action :toggle, on: :click
            end
          end
        end

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

        style :variant, default: :default, required: true, variants: VARIANTS
        style :size, default: :default, required: true, variants: SIZES

        option :pressed, :boolean, default: false
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
        # ships (the golden Button's rule).
        def before_render
          return if label.present? || visible_text?

          raise ArgumentError,
                "icon-only Toggle requires label: (the accessible name, state-invariant - " \
                "'Bookmark', never 'Remove bookmark')"
        end

        def call
          content_tag(:button, content, **root_attributes.to_attributes)
        end

        def root_attributes
          attrs = {
            "type" => "button", "data-slot" => "toggle",
            "aria-pressed" => pressed.to_s,
            "data-variant" => variant, "data-size" => size,
            "disabled" => disabled
          }
          # Base UI presence boolean: pressed -> bare data-pressed,
          # unpressed -> attribute absent (never data-pressed=false).
          attrs["data-pressed"] = "" if pressed
          # Radix emits data-disabled alongside native disabled - kept for
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
