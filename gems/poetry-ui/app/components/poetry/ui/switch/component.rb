# frozen_string_literal: true

module Poetry
  module Ui
    module Switch
      # Second of the toggle family (Switch) - the
      # instant-effect on/off control: Checkbox's architecture wearing a
      # different ARIA skin and a thumb. Same store inversion (the hidden
      # native input is the form participant and the store), same
      # poetry--core--checked controller reused VERBATIM (zero fork - the
      # deltas are markup/validation-level). The contract deltas:
      # role="switch", aria-checked strictly true|false (NEVER "mixed" -
      # :indeterminate raises ArgumentError), Enter is NOT suppressed (the
      # controller's Enter guard keys off role=checkbox - Radix-exact
      # asymmetry), and the size variant is carried entirely by data-size +
      # group/switch selectors.
      #
      # Doctrine: a Switch flips an effect IMMEDIATELY (announces on/off);
      # a Checkbox stages a value for submit. name: exists because settings
      # forms submit switches too - the flagship recipe is the Turbo
      # auto-submit (form data-action: "change->form#requestSubmit" hangs
      # off the store input's REAL change event).
      class Component < Poetry::Core::Component
        CHECKED = %i[poetry core checked].freeze
        SIZES = %i[default sm].freeze

        AGENT_RULES = [
          "Use poetry_switch - never a styled checkbox pretending to be a switch (role=switch announces " \
          "on/off; that's the point).",
          "Switch = instant effect; Checkbox = staged for submit. If nothing happens until a Save " \
          "button, use Checkbox.",
          "Every switch needs an accessible name (Label/Field for= or label:).",
          "Switches are BINARY - no indeterminate, ever (ArgumentError). A third state means a " \
          "different component.",
          "The instant-effect recipe pairs the flip with server persistence (Turbo auto-submit) - " \
          "never flip UI-only for a setting the user believes is saved.",
          "NEVER write the checked attributes (data-checked/data-unchecked) without aria-checked and " \
          "the input sync (the controller writes all three)."
        ].freeze

        # data-size on the control; the thumb reads it via
        # group-data-[size=*]/switch - no per-element size classes.
        style :size, default: :default, required: true, variants: SIZES

        option :checked, :boolean, default: false
        option :name, :string
        option :value, :string, default: "1"
        option :unchecked_value, :string, default: "0"
        option :disabled, :boolean, default: false
        # aria-required ONLY, never native required (the Field lock).
        option :required, :boolean, default: false
        option :label, :string

        def initialize(attributes = {})
          # A switch is strictly binary: aria-checked on role=switch must
          # never be "mixed" - the violation is unrepresentable (the base-contract
          # base-contract borrow). Guarded BEFORE the boolean cast would
          # silently truthy it away.
          if attributes.values_at(:checked, "checked").any? { |value| value.to_s == "indeterminate" }
            raise ArgumentError, "Switch is strictly binary - no :indeterminate (use Checkbox for tri-state)"
          end

          super
        end

        def state
          checked ? "checked" : "unchecked"
        end

        def control_id
          @control_id ||= html_attributes["id"].presence || "poetry-switch-#{SecureRandom.hex(4)}"
        end

        def input_id
          "#{control_id}-input"
        end

        def form_participant?
          name.present?
        end

        def root_attributes
          attrs = {
            "type" => "button", "role" => "switch", "id" => control_id,
            "aria-checked" => checked.to_s, "data-#{state}" => "",
            "data-slot" => "switch", "data-size" => size, "disabled" => disabled
          }
          attrs["aria-required"] = true if required
          attrs["aria-label"] = label if label.present?
          html_attributes.merge_if_not_set(
            attrs.merge(root_stimulus_attributes).merge(component_data_attributes)
          )
        end

        private

        # The SHARED family controller (shipped by Checkbox, reused with
        # zero fork): input first, real change event, then reflect.
        def root_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          builder = Poetry::Core::Stimulus::Builder.new(CHECKED, attrs)
          builder.register_controller
          builder.with_value(:input_id, input_id) if form_participant?
          builder.with_action(:toggle, on: :click)
          attrs.to_attributes
        end
      end
    end
  end
end
