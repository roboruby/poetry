# frozen_string_literal: true

module Poetry
  module Ui
    # Content surface cards.
    module Card
      # A content surface composed from slots: a header (title,
      # description, and a trailing corner action), the body content
      # block, and a footer row. The header grid gains its trailing
      # column automatically when an action is present, and the title
      # renders as a real heading (h3 by default - set title_tag: to fit
      # the page outline).
      #
      # @example
      #   render Poetry::Ui::Card::Component.new do |card|
      #     card.with_title { "Team" }
      #     card.with_description { "Invite and manage members." }
      #     "Body content"
      #   end
      class Component < Poetry::Core::Component
        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Compose with the slots (title/description/action/footer) - never rebuild the header grid by hand.",
          "The card body is the content block; use CardAction for the header-corner control.",
          "The title renders as a real heading (h3 default) - set title_tag: to fit the page outline."
        ].freeze

        slot_doc :title, "The heading line, rendered as a real heading element (title_tag:)."
        renders_one :title
        slot_doc :description, "Muted one-liner under the title."
        renders_one :description
        slot_doc :action, "The header's trailing corner control (a button, menu, or link)."
        renders_one :action
        slot_doc :footer, "The bottom row (actions/meta). class: merges into the footer div (a border-t divider is " \
                          "the canonical use); every other option (id:, data:, ...) rides onto the footer div " \
                          "verbatim."
        renders_one :footer, lambda { |**options, &block|
          @footer_options = options
          @footer_block = block
          nil
        }

        option :title_tag, :symbol, default: :h3,
                                    doc: "The heading element for the title - pick it to fit the page outline."

        option :content_class, :string,
               doc: "Extra classes merged into the body cell (caller classes win). A chat-in-a-card layout passes " \
                    "min-h-0 flex-1 p-0 so the transcript can flex and scroll."

        option :header_class, :string,
               doc: "Extra classes merged into the header row - border-b rules the title off from the body."

        validates :title_tag, inclusion: { in: %i[h1 h2 h3 h4 h5 h6] }

        part "card", "Root container - the vertical flex stack"
        part "card-header", "The title row grid - gains a trailing auto column when " \
                            "card-action is present"
        part "card-title", "The heading (title_tag, h3 by default)"
        part "card-description", "Muted one-liner under the title"
        part "card-action", "The header's trailing corner control"
        part "card-content", "The body - the content block renders here"
        part "card-footer", "The bottom row (actions/meta)"

        # The caller's footer block, captured by with_footer.
        # @api private
        attr_reader :footer_block

        # @api private
        def footer_attributes
          options = (@footer_options || {}).dup
          { "data-slot" => "card-footer",
            class: css(:footer, class: options.delete(:class)) }.merge(options)
        end

        # Whether any header slot is set.
        # @api private
        def header?
          title? || description? || action?
        end

        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "card" }.merge(component_data_attributes)
          )
        end

        private :footer_attributes, :header?, :root_attributes
      end
    end
  end
end
