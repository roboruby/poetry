# frozen_string_literal: true

module Poetry
  module Ui
    # Instant-effect on/off controls.
    module Switch
      # An on/off control whose effect applies immediately - flip it and
      # the change happens now, where a Checkbox stages a value for a
      # later submit. Renders a button[role=switch] backed by a hidden
      # native input: give it name: and it participates in form
      # submission and fires a real change event on toggle, so a settings
      # form can auto-submit (e.g. Turbo's
      # data-action: "change->form#requestSubmit").
      #
      # A switch is strictly binary - :indeterminate raises ArgumentError.
      # Give every switch an accessible name via label: or a paired
      # Label/Field.
      #
      # @example A named setting switch
      #   render Poetry::Ui::Switch::Component.new(name: "notifications", checked: true,
      #                                            label: "Email notifications")
      class Component < Poetry::Core::Component
        # The closed vocabulary for the size axis.
        SIZES = %i[default sm].freeze

        # Projected into the registry, llms.txt, and the agent surface.
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

        # Click toggles the hidden input first (firing a real change
        # event), then reflects the new state onto the control.
        use_stimulus do
          on :root do
            controller :checked do
              register
              value :input_id, if: :form_participant?
              action :toggle, on: :click
            end
          end
        end

        style :size, default: :default, required: true, variants: SIZES,
                     doc: "The control's size axis; the thumb scales to match."

        option :checked, :boolean, default: false, doc: "The server-rendered on/off state."
        option :name, :string, doc: "Names the hidden input, making the switch a form participant."
        option :value, :string, default: "1", doc: "Submitted when the switch is on. Ignored without name:."
        option :unchecked_value, :string, default: "0",
                                          doc: "Submitted when the switch is off, so the field always posts. Ignored " \
                                               "without name:."
        option :disabled, :boolean, default: false,
                                    doc: "Disables the control and its hidden input - a disabled switch neither " \
                                         "toggles nor submits."
        option :required, :boolean, default: false,
                                    doc: "Marks the switch required via aria-required (never the native attribute)."
        option :label, :string, doc: "The accessible name, rendered as aria-label - not visible text."

        part "switch", "The visual button[role=switch] - reflects the hidden input via " \
                       "aria-checked plus the checked pair (never indeterminate)",
             states: {
               "data-checked" => "on (the shared checked controller reflects every toggle " \
                                 "here, aria-checked in step)",
               "data-unchecked" => "off (the server-rendered default)",
               "data-size" => { condition: "always - the resolved size (the thumb reads it " \
                                           "via group/switch selectors)",
                                values: SIZES.map(&:to_s) }
             }
        part "switch-thumb", "The sliding knob - travel is pure CSS off the checked pair",
             states: {
               "data-checked" => "mirrors the control (the controller reflects state on " \
                                 "every part wearing the pair)",
               "data-unchecked" => "mirrors the control - the thumb sits at the start"
             }

        # @api private
        def initialize(attributes = {})
          # A switch is strictly binary: aria-checked on role=switch must
          # never be "mixed" - the violation is unrepresentable. Guarded
          # BEFORE the boolean cast would silently truthy it away.
          if attributes.values_at(:checked, "checked").any? { |value| value.to_s == "indeterminate" }
            raise ArgumentError, "Switch is strictly binary - no :indeterminate (use Checkbox for tri-state)"
          end

          super
        end

        # @api private
        def state
          checked ? "checked" : "unchecked"
        end

        # @api private
        def control_id
          @control_id ||= poetry_instance_id("poetry-switch")
        end

        # @api private
        def input_id
          "#{control_id}-input"
        end

        # @api private
        def form_participant?
          name.present?
        end

        # @api private
        def root_attributes
          attrs = {
            "type" => "button", "role" => "switch", "id" => control_id,
            "aria-checked" => checked.to_s, "data-#{state}" => "",
            "data-slot" => "switch", "data-size" => size, "disabled" => disabled
          }
          attrs["aria-required"] = true if required
          attrs["aria-label"] = label if label.present?
          html_attributes.merge_if_not_set(
            attrs.merge(stimulus_attributes_for(:root)).merge(component_data_attributes)
          )
        end

        private :state, :control_id, :input_id, :form_participant?, :root_attributes
      end
    end
  end
end
