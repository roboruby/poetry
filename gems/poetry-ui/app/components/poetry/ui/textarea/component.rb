# frozen_string_literal: true

module Poetry
  module Ui
    module Textarea
      # Input's multiline sibling: the
      # native <textarea> on poetry's semantic tokens, template-less,
      # ZERO JS - auto-grow is the field-sizing-content CSS property
      # (unsupported browsers keep min-h-16/rows: + the native resize
      # handle: a feature, not a bug). The value renders as element
      # CONTENT (textarea semantics), so the escape surface is the
      # </textarea> breakout - ERB/content_tag escaping covers it and a
      # render test pins it permanently. All the a11y work happens at the
      # Field layer (label pairing, describedby, aria-invalid,
      # aria-required-not-native) - this component just refuses to bypass
      # it.
      #
      # @example A free-text field
      #   render Poetry::Ui::Textarea::Component.new(name: "bio", rows: 4,
      #                                              placeholder: "Tell us about yourself")
      class Component < Poetry::Core::Component
        AGENT_RULES = [
          "Wire through Field/FormBuilder (control_attributes) - never hand-write the aria plumbing.",
          "Placeholder is NOT a label - pair with Label/Field always.",
          "Use Textarea for free text; Input for single-line; do not bolt a JS autosizer on " \
          "(auto-grow is CSS).",
          "Do not set native required - required flows as aria-required via Field."
        ].freeze

        option :name, :string
        option :value, :string
        option :placeholder, :string
        # Initial visual rows; with field-sizing-content it acts as the
        # minimum height alongside min-h-16 (and the unsupported-browser
        # fallback size).
        option :rows, :integer
        option :disabled, :boolean, default: false
        # aria-invalid -> the destructive ring; set by Field/FormBuilder
        # from model errors.
        option :invalid, :boolean, default: false

        part "textarea", "The <textarea> element itself - value renders as content; " \
                         "auto-grow is the field-sizing-content CSS property, zero JS"

        def call
          # value as CONTENT (escaped by content_tag - the </textarea>
          # injection surface).
          content_tag(:textarea, value, **root_attributes.to_attributes)
        end

        def root_attributes
          attrs = { "data-slot" => "textarea" }.merge(component_data_attributes)
          attrs["name"] = name if name.present?
          attrs["placeholder"] = placeholder if placeholder.present?
          attrs["rows"] = rows if rows.present?
          attrs["disabled"] = true if disabled
          attrs["aria-invalid"] = true if invalid
          html_attributes.merge_if_not_set(attrs)
        end
      end
    end
  end
end
