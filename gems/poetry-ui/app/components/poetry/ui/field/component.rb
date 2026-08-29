# frozen_string_literal: true

module Poetry
  module Ui
    # The Field family - the label/control/hint/error wrapper for one form control.
    module Field
      # The Field wrapper - label, control, hint, and error as one unit
      # with the aria wiring done for you: the control (the content
      # block) receives its id from the field, and control_attributes
      # carries aria-invalid + aria-describedby pointing at the hint and
      # error ids. The FormBuilder composes this from model truth; Field
      # itself is model-agnostic.
      #
      # @example
      #   render Poetry::Ui::Field::Component.new(
      #     id: "email", label_text: "Email", hint: "We never share it."
      #   ) do |field|
      #     tag.input(type: "email", name: "email", **field.control_attributes)
      #   end
      class Component < Poetry::Core::Component
        # The closed vocabulary for the orientation axis.
        ORIENTATIONS = %i[vertical horizontal setting responsive].freeze

        # The closed vocabulary for the hint_position axis.
        HINT_POSITIONS = %i[below above].freeze

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Wire the control with field.control_attributes - never hand-write aria-describedby.",
          "Error text arrives via error: (from model errors upstream) - never a bare red <p>.",
          "hint: (escaped string) for pure data; with_hint { } for authored markup (links) - " \
          "call it BEFORE the control so the hint id lands in aria-describedby.",
          "orientation: :horizontal is the boolean-control layout (checkbox/switch left, " \
          "label + hint stacked right) - text inputs and groups stay vertical.",
          "orientation: :responsive stacks by default and flips label-left / control-right " \
          "once its poetry_field_group container passes the md mark - the settings-page " \
          "recipe (it needs that FieldGroup ancestor to measure against)."
        ].freeze

        style :orientation, default: :vertical, required: true, variants: ORIENTATIONS,
                            doc: "The layout axis. :horizontal is the boolean-control pattern: the control lands in " \
                                 "the first grid column, label + hint/error stack in the second, and the control " \
                                 "row-centers against the label line."

        option :id, :string, required: true, doc: "The control's DOM id - the hint/error/label ids derive from it."
        option :label_text, :string, doc: "The visible label text, associated with the control via for=."
        option :hint, :string,
               doc: "Plain-text guidance under the control (escaped wholesale); use with_hint for authored markup."
        option :hint_position, :symbol, default: :below,
                                        doc: "Where the hint renders relative to the control - :above puts guidance " \
                                             "before a tall control. aria-describedby is identical either way; this " \
                                             "is visual order only."
        option :error, :string,
               doc: "The error line (typically from model errors) - presence flips the invalid skin and leads the " \
                    "control's aria-describedby."
        option :invalid, :boolean, default: false,
                                   doc: "Flips the invalid skin (data-invalid + aria-invalid) WITHOUT an error line. " \
                                        "error: implies it; use invalid: alone when the hint copy IS the " \
                                        "requirement."
        option :required, :boolean, default: false,
                                    doc: "Marks the control required via aria-required only - never the native " \
                                         "required attribute."
        option :group, :boolean, default: false,
                                 doc: "group: the control is a role-bearing <div> (RadioGroup, Slider) - label[for] " \
                                      "would be inert (Chrome flags it), so the label drops for=, carries label_id, " \
                                      "and control_attributes names the group via aria-labelledby (the visible " \
                                      "label, i18n-proof)."

        part "field", "The quartet's grid root - label, control, hint, and error stack inside",
             states: {
               "data-invalid" => { condition: "always - true when error: is present " \
                                              "or invalid: is set, else false",
                                   values: %w[true false] },
               "data-orientation" => { condition: "always - the resolved orientation " \
                                                  "(horizontal is the boolean-control layout)",
                                       values: ORIENTATIONS.map(&:to_s) }
             }
        part "field-label", "The Label (composed) wearing the source's field-label slot - names the control"
        part "field-description", "The hint <p> (the source's description) - its id lands in the control's " \
                                  "aria-describedby"
        part "field-error", "The error <p> - present only when error: is set; its id leads " \
                            "the control's aria-describedby"
        part "checkbox-input", "A nested Checkbox's hidden native input - the toggle renders " \
                               "as a wrapper-free fragment, so its sibling form store sits " \
                               "directly in the field's DOM (the horizontal boolean-control " \
                               "layout)"
        part "switch-input", "A nested Switch's hidden native input - the same wrapper-free " \
                             "fragment escape as checkbox-input (the setting-row layout)"

        # Validates hint_position and forces the content capture.
        # @api private
        def before_render
          # Force the content block first: with_hint registers during the
          # capture, and the template's hint tag must see it.
          content

          return if HINT_POSITIONS.include?(hint_position)

          raise ArgumentError, "Field hint_position: #{hint_position.inspect} must be one of " \
                               "#{HINT_POSITIONS.inspect}"
        end

        # The hint element's id (referenced from aria-describedby).
        # @api private
        def hint_id = "#{id}-hint"
        # The error element's id (leads aria-describedby).
        # @api private
        def error_id = "#{id}-error"
        # The label element's id (referenced from aria-labelledby when group:).
        # @api private
        def label_id = "#{id}-label"

        # Block-form hint for authored markup - a link or emphasis inside
        # the guidance. Call it BEFORE the control renders, so the hint id
        # lands in the control's aria-describedby; conflicts with hint: -
        # use one or the other. The captured buffer renders as-is and is
        # never re-blessed: ERB-authored markup stays markup, every
        # interpolated value escapes normally, and a plain-String return
        # is escaped by capture. Untrusted data belongs in hint: (escaped
        # wholesale) or inside <%= %> in the block - never pre-marked
        # html_safe.
        #
        # @example A hint containing a link
        #   <% field.with_hint do %>
        #     Forgot it? <%= link_to "Reset your password", reset_path %>
        #   <% end %>
        def with_hint(&block)
          raise ArgumentError, "Field with_hint conflicts with hint: - use one or the other" if hint.present?
          if @control_attributes_issued
            raise ArgumentError, "Field with_hint must be called before the control renders - " \
                                 "control_attributes already handed out aria-describedby " \
                                 "without the hint id"
          end

          @hint_block = block
          self
        end

        # The captured hint block, consumed by the template.
        # @api private
        attr_reader :hint_block

        # Whether any hint (string or block form) is present.
        # @api private
        def hint_present? = hint.present? || !@hint_block.nil?

        # Whether the field wears the invalid skin (error: or invalid:).
        # @api private
        def invalid? = invalid || error.present?

        # Everything the control inside the field must carry - the id,
        # aria-describedby (error id first, then hint id), aria-invalid,
        # aria-required, and aria-labelledby when group:. Merge it into
        # the control's attributes (the FormBuilder does this for you).
        def control_attributes
          @control_attributes_issued = true
          attrs = { "id" => id }
          attrs["aria-labelledby"] = label_id if group && label_text.present?
          describedby = []
          describedby << error_id if error.present?
          describedby << hint_id if hint_present?
          attrs["aria-describedby"] = describedby.join(" ") if describedby.any?
          attrs["aria-invalid"] = true if invalid?
          # The aria-required-only rule: never the native required
          # attribute - no native bubbles, no double announcement.
          attrs["aria-required"] = true if required
          attrs
        end

        # The quartet root's attributes.
        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "field", "data-invalid" => invalid?,
              "data-orientation" => orientation }.merge(component_data_attributes)
          )
        end

        private :hint_present?, :root_attributes
      end
    end
  end
end
