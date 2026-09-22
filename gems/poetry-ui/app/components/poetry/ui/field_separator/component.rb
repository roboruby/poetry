# frozen_string_literal: true

module Poetry
  module Ui
    # The FieldSeparator family - the divider row between stacked fields.
    module FieldSeparator
      # The FieldSeparator - the labelled rule: a Separator drawn across
      # the row with an optional inline caption riding on top ("Or
      # continue with"). Between stacked fields in a FieldGroup, under a
      # sign-in form before the provider buttons, at a date break in a
      # list - anywhere a rule needs a caption. The caption is visual
      # chrome on a decorative rule - the Separator inside stays
      # aria-hidden either way.
      #
      # @example A captioned divider between stacked fields
      #   render Poetry::Ui::FieldSeparator::Component.new { "Or continue with" }
      class Component < Poetry::Core::Component
        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "The labelled rule, anywhere: between stacked fields in a poetry_field_group, under a sign-in " \
          "form (\"Or continue with\"), at a date break; poetry_separator is the bare rule.",
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

        # Renders the divider row (rule + optional caption).
        # @api private
        def call
          content_tag(:div, **root_attributes) do
            safe_join([rule, caption].compact)
          end
        end

        # The divider row's attributes.
        def root_attributes
          super(
            # Normalized to "true"/"false": ViewComponent's content? is
            # truthy/falsy, not boolean (defined?-strings, blocks), Rails
            # drops false attribute values, and the declared-state
            # contract wants the pair always visible.
            { "data-content" => (content? ? "true" : "false") }
          )
        end

        private

        # The separator line.
        def rule
          render(Separator::Component.new(class: css(:line)))
        end

        # The caption span, or nil without content.
        def caption
          return unless content?

          content_tag(:span, content, "data-slot" => "field-separator-content",
                                      "class" => css(:content))
        end
      end
    end
  end
end
