# frozen_string_literal: true

module Poetry
  module Motion
    module ScrollProgress
      # A thin bar that fills as the reader scrolls the page, or one long
      # element (target:). It is decorative feedback on the reader's own
      # scrolling, so it keeps following under reduced motion; the server
      # renders it empty. Place it in the layout, or at the top of the
      # element it follows.
      #
      # @example A reading bar for an article
      #   <%= poetry_scroll_progress(target: "article") %>
      #   <article id="article">...</article>
      class Component < Poetry::Core::Component
        # Where the bar sits.
        POSITIONS = %i[top bottom inline].freeze

        AGENT_RULES = [
          "Use one scroll progress bar per page, for long reading; it is decorative and never the only " \
          "sign of where the reader is."
        ].freeze

        use_behavior :scroll_value

        use_stimulus do
          on :root do
            controller :scroll_progress do
              register
              value :target_id, from: :target_id, if: -> { target.present? }
            end
          end
        end

        option :target, :string, doc: "The id of the element whose scroll the bar follows; the page when blank."
        option :position, :symbol, default: :top,
                                   doc: "top or bottom pins the bar to the viewport edge; inline leaves it in place."

        validates :position, inclusion: { in: POSITIONS }

        part "scroll-progress", "The bar; it fills from the start edge",
             states: { "data-position" => { condition: "always - where the bar sits",
                                            values: POSITIONS.map(&:to_s) } },
             vars: { "--scroll-progress" => "how far the reader has scrolled, 0 to 1" }

        def call
          tag.div(**root_attributes)
        end

        def root_attributes
          super("aria-hidden" => "true", "data-position" => position)
        end

        private

        def target_id = target.to_s
      end
    end
  end
end
