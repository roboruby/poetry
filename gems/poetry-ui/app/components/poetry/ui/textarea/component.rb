# frozen_string_literal: true

module Poetry
  module Ui
    # Multiline free-text inputs.
    module Textarea
      # A multiline free-text input: the native <textarea> with the
      # library's styling and zero JS. It auto-grows with its content via
      # CSS (the field-sizing-content property); browsers without support
      # keep the rows:/minimum-height sizing plus the native resize
      # handle. Label pairing, description wiring, and error state flow
      # in from the Field/FormBuilder layer - use Input for single-line
      # text.
      #
      # @example A free-text field
      #   render Poetry::Ui::Textarea::Component.new(name: "bio", rows: 4,
      #                                              placeholder: "Tell us about yourself")
      class Component < Poetry::Core::Component
        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Wire through Field/FormBuilder (control_attributes) - never hand-write the aria plumbing.",
          "Placeholder is NOT a label - pair with Label/Field always.",
          "Use Textarea for free text; Input for single-line; do not bolt a JS autosizer on " \
          "(auto-grow is CSS).",
          "Do not set native required - required flows as aria-required via Field."
        ].freeze

        option :name, :string, doc: "The submitted field name."
        option :value, :string, doc: "The initial text, rendered as the element's content."
        option :placeholder, :string, doc: "Hint text shown while empty - never a substitute for a label."
        option :rows, :integer,
               doc: "The initial visual rows - the minimum height under CSS auto-grow, and the fixed size in " \
                    "browsers without it."
        option :disabled, :boolean, default: false, doc: "Disables the control and forwards to the native element."
        option :invalid, :boolean, default: false,
                                   doc: "Marks the field errored (aria-invalid + the destructive ring); set by " \
                                        "Field/FormBuilder from model errors."

        part "textarea", "The <textarea> element itself - value renders as content; " \
                         "auto-grow is the field-sizing-content CSS property, zero JS"

        # @api private
        def call
          # value as CONTENT (escaped by content_tag - the </textarea>
          # injection surface).
          content_tag(:textarea, value, **root_attributes.to_attributes)
        end

        # @api private
        def root_attributes
          attrs = { "data-slot" => "textarea" }.merge(component_data_attributes)
          attrs["name"] = name if name.present?
          attrs["placeholder"] = placeholder if placeholder.present?
          attrs["rows"] = rows if rows.present?
          attrs["disabled"] = true if disabled
          attrs["aria-invalid"] = true if invalid
          html_attributes.merge_if_not_set(attrs)
        end

        private :root_attributes
      end
    end
  end
end
