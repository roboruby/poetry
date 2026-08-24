# frozen_string_literal: true

module Poetry
  module Ui
    module SearchField
      # The SearchField: a type=search
      # input on InputGroup's chrome - leading search glyph, trailing
      # clear affordance. The seams live in poetry--core--search-field:
      # Escape CLEARS a non-empty field and is consumed (the NEXT press
      # reaches the dismissal layer), an empty field lets it propagate;
      # the clear button never steals focus (mobile keyboards stay up)
      # and is tabindex -1 - keyboard users already have Escape. Enter is
      # never intercepted: native form submission is the Rails path. The
      # native WebKit cancel affordance is suppressed so poetry's clear
      # button is the only one.
      #
      # @example
      #   render Poetry::Ui::SearchField::Component.new(name: "q", label: "Search", placeholder: "Search...")
      class Component < Poetry::Core::Component
        include Poetry::Ui::InputGroupField
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

        option :name, :string, required: true
        option :value, :string
        option :placeholder, :string
        option :id, :string
        option :label, :string
        option :described_by, :string
        option :disabled, :boolean, default: false
        option :readonly, :boolean, default: false
        option :required, :boolean, default: false
        option :invalid, :boolean, default: false

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
        # data-slot=search-field-clear on Button's root - ownership
        # attributes it to Button (the NumberField stepper pattern), so it
        # is documented here in prose only: tabindex -1 (Escape is the
        # keyboard path), hidden while empty, never steals focus.

        def root_attributes
          attrs = {
            "data-slot" => "search-field",
            "class" => css
          }.merge(component_data_attributes)
          attrs["data-empty"] = "" if value.blank?
          html_attributes.merge_if_not_set(attrs.merge(stimulus_attributes_for(:root)))
        end

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

        # The clear affordance: a ghost icon Button (the NumberField
        # stepper chrome) that is NEVER a tab stop and never steals focus.
        def clear_button
          group_tool_button(slot: "search-field-clear",
                            label: t("poetry.search_field.clear"),
                            extra: { "hidden" => value.blank? || readonly || disabled ? "" : nil },
                            wiring: stimulus_attributes_for(:clear))
        end
      end
    end
  end
end
