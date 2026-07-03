# frozen_string_literal: true

module Poetry
  module Ui
    module Textarea
      # The Textarea preview matrix: the five shadcn examples (demo,
      # disabled, with-label, with-text, with-button) plus the invalid
      # state and long auto-grown content.
      class Preview < Poetry::Core::Preview::Base
        # @!group States

        def default
          render_component(placeholder: "Type your message here.")
        end

        def disabled
          render_component(placeholder: "Type your message here.", disabled: true)
        end

        def invalid
          render_component(placeholder: "Type your message here.", invalid: true,
                           value: "too short")
        end

        # field-sizing-content auto-grows with the content (Chromium);
        # elsewhere: min-h-16 + the native resize handle.
        def auto_grown
          render_component(value: "Paragraph one.\n\nParagraph two keeps pushing the height - " \
                                  "no JS autosizer, the CSS does it.\n\nParagraph three.")
        end

        def taller_start
          render_component(rows: 8, placeholder: "Starts eight rows tall.")
        end

        # @!endgroup

        # @!group Recipes

        # textarea-with-label parity (Label pairs by for=).
        def with_label
          render_component(Field::Component.new(id: "preview-message", label_text: "Your message")) do
            embed(Component.new(name: "message", placeholder: "Type your message here.",
                                id: "preview-message"))
          end
        end

        # textarea-with-text parity: the hint wires via describedby.
        def with_hint
          field = Field::Component.new(
            id: "preview-bio", label_text: "Bio",
            hint: "Your message will be copied to the support team."
          )
          render_component(field) do
            embed(Component.new(name: "bio", placeholder: "Tell us about yourself",
                                **field.control_attributes.transform_keys(&:to_sym)))
          end
        end

        # Model-error rendering: aria-invalid + error-before-hint.
        def with_error
          field = Field::Component.new(
            id: "preview-report", label_text: "Report",
            hint: "Markdown is supported.", error: "can't be blank", required: true
          )
          render_component(field) do
            embed(Component.new(name: "report", **field.control_attributes.transform_keys(&:to_sym)))
          end
        end

        # @!endgroup
      end
    end
  end
end
