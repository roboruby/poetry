# frozen_string_literal: true

module Poetry
  module Ui
    # A search input with a leading glyph and a clear affordance.
    module SearchField
      # A type=search input on the bordered group chrome - leading search
      # glyph, trailing clear affordance. Escape CLEARS a non-empty field
      # and is consumed (the NEXT press reaches the dismissal layer), an
      # empty field lets it propagate; the clear button never steals focus
      # (mobile keyboards stay up) and is not a tab stop - keyboard users
      # already have Escape. Enter is never intercepted: native form
      # submission is the Rails path. The native WebKit cancel affordance
      # is suppressed so the clear button is the only one.
      #
      # @example
      #   render Poetry::Ui::SearchField::Component.new(name: "q", label: "Search", placeholder: "Search...")
      class Component < Poetry::Core::Component
        include Poetry::Ui::InputGroupField

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Search inputs are a SearchField (poetry_search_field) - never a bare Input with a " \
          "hand-rolled clear button; Escape-clears and focus retention ride the controller.",
          "Enter submits the surrounding form natively - wrap it in a form/turbo-frame for " \
          "live search; listen for poetry:search-field:clear to reset results.",
          "Pair with a Label/Field for the accessible name, or pass label: standalone."
        ].freeze

        use_stimulus do
          on :root do
            controller(:search_field) { register }
          end
          on :input do
            controller :search_field do
              target :input
              action :changed, on: :input
              action :keydown, on: :keydown
            end
          end
          # The clear affordance holds focus through pointerdown (never a
          # tab stop) and clears on click.
          on :clear do
            controller :search_field do
              target :clear
              action :holdFocus, on: :pointerdown
              action :clear, on: :click
            end
          end
        end

        option :name, :string, required: true, doc: "The form field name on the search input."
        option :value, :string, doc: "The pre-filled query; presence unhides the clear affordance."
        option :placeholder, :string, doc: "Hint text shown while the field is empty."
        option :id, :string, doc: "The input's DOM id - what a Field label's for: must reference."
        option :label, :string,
               doc: "The accessible name (aria-label) for standalone use - or pair with a Label/Field instead."
        option :described_by, :string, doc: "aria-describedby on the input - Field hint/error wiring."
        option :disabled, :boolean, default: false, doc: "Disables the input and hides the clear affordance."
        option :readonly, :boolean, default: false,
                                    doc: "The query can be read but not edited; the clear affordance hides."
        option :required, :boolean, default: false, doc: "Marks the input required for native constraint validation."
        option :invalid, :boolean, default: false,
                                   doc: "aria-invalid on the input - set by Field/FormBuilder from model errors."

        part "search-field", "Root - the controller and the emptiness state ride here",
             states: {
               "data-empty" => "the input holds no text (server-set, controller-kept; hides " \
                               "the clear affordance)"
             }
        part "input-group-addon", "The leading search-glyph cell - InputGroup's addon " \
                                  "vocabulary (the NumberField precedent)",
             states: {
               "data-align" => { condition: "always - inline-start holds the glyph, " \
                                            "inline-end the clear button",
                                 values: %w[inline-start inline-end] }
             }
        part "search-field-group", "The bordered field surface - InputGroup's chrome, focus " \
                                   "ring keyed on the control inside"
        part "input-group-control", "The native <input type=search> - InputGroup's control " \
                                    "slot (the themes' focus-ring hook); WebKit's own cancel " \
                                    "affordance suppressed"
        # The clear affordance renders as a composed ghost Button carrying
        # data-slot=search-field-clear on Button's root - part ownership
        # attributes it to Button, so it is documented here in prose only:
        # tabindex -1 (Escape is the keyboard path), hidden while empty,
        # never steals focus.

        # @api private
        def root_attributes
          attrs = {
            "data-slot" => "search-field",
            "class" => css
          }.merge(component_data_attributes)
          attrs["data-empty"] = "" if value.blank?
          html_attributes.merge_if_not_set(attrs.merge(stimulus_attributes_for(:root)))
        end

        # @api private
        def input_attributes
          attrs = Poetry::Core::HTML::Attributes.new(
            "type" => "search",
            "name" => name,
            "id" => control_id,
            "data-slot" => "input-group-control",
            "class" => "#{Input::Style.css(class: InputGroup::Style.css(:control_input))} #{css(:input)}",
            "autocomplete" => "off",
            "autocorrect" => "off",
            "spellcheck" => "false"
          )
          attrs["value"] = value if value.present?
          attrs["placeholder"] = placeholder if placeholder.present?
          attrs["aria-label"] = label if label.present?
          attrs["aria-invalid"] = "true" if invalid && !disabled
          attrs["aria-describedby"] = described_by if described_by.present?
          attrs["disabled"] = "" if disabled
          attrs["readonly"] = "" if readonly
          attrs["required"] = "" if required
          attrs.merge!(stimulus_attributes_for(:input))
          attrs
        end

        # The clear affordance: a ghost icon Button that is NEVER a tab
        # stop and never steals focus.
        # @api private
        def clear_button
          group_tool_button(slot: "search-field-clear",
                            label: t("poetry.search_field.clear"),
                            extra: { "hidden" => value.blank? || readonly || disabled ? "" : nil },
                            wiring: stimulus_attributes_for(:clear))
        end

        private :root_attributes, :input_attributes, :clear_button
      end
    end
  end
end
