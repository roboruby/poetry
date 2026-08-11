# frozen_string_literal: true

module Poetry
  module Ui
    module FieldSeparator
      # The FieldSeparator - the divider between stacked fields inside a
      # FieldGroup (upstream FieldSeparator): a Separator drawn across the
      # row, with an optional inline caption riding on top ("Or continue
      # with"). The caption is visual chrome on a decorative rule - the
      # Separator inside stays aria-hidden either way.
      class Component < Poetry::Core::Component
        AGENT_RULES = [
          "Divides stacked fields inside a poetry_field_group - not a general-purpose rule " \
          "(that is poetry_separator).",
          "Pass a block for the inline caption form (\"Or continue with\") - the caption sits " \
          "on the line, backed by the page background."
        ].freeze

        part "field-separator", "The divider row - a decorative Separator drawn across it",
             states: {
               "data-content" => { condition: "always - whether the inline caption renders",
                                   values: %w[true false] }
             }
        part "field-separator-content", "The inline caption span (block content) - sits on " \
                                        "the line, backed by the page background"

        def call
          content_tag(:div, **root_attributes.to_attributes) do
            safe_join([rule, caption].compact)
          end
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            # Normalized to "true"/"false": ViewComponent's content? is
            # truthy/falsy, not boolean (defined?-strings, blocks), Rails
            # drops false attribute values, and the declared-state
            # contract wants the pair always visible.
            { "data-slot" => "field-separator", "data-content" => (content? ? "true" : "false") }
              .merge(component_data_attributes)
          )
        end

        private

        def rule
          render(Separator::Component.new(class: css(:line)))
        end

        def caption
          return unless content?

          content_tag(:span, content, "data-slot" => "field-separator-content",
                                      "class" => css(:content))
        end
      end
    end
  end
end
