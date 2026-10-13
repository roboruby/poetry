# frozen_string_literal: true

module Poetry
  module Motion
    module TextReveal
      # A passage whose words brighten one after another as it scrolls into
      # view. The server renders every word at full strength and the whole
      # text once for screen readers; the words are aria-hidden spans, so
      # the reveal never chops what a reader hears. The scroll writes one
      # custom property; under reduced motion the text is simply there.
      #
      # @example
      #   <%= poetry_text_reveal("Poetry renders the finished page on the server.") %>
      class Component < Poetry::Core::Component
        include Poetry::Motion::Options

        # The tags the passage can render as.
        TAGS = %i[p h1 h2 h3 h4 blockquote div].freeze

        AGENT_RULES = [
          "Text reveal is for a short passage of plain text (a statement, a quote), never body copy, " \
          "links or form labels: the words are rebuilt as spans."
        ].freeze

        use_behavior :scroll_value

        use_stimulus do
          on :root do
            controller(:text_reveal, if: :animate) { register }
          end
        end

        motion_options
        option :text, :string, required: true, doc: "The passage, plain text."
        option :tag, :symbol, default: :p, doc: "The element the passage renders as."

        validates :tag, inclusion: { in: TAGS }

        part "text-reveal", "The passage; --reveal-progress (0 to 1) brightens its words",
             vars: { "--reveal-progress" => "how far the reveal has come, 1 when finished",
                     "--reveal-count" => "how many words the passage has" }
        part "text-reveal-word", "One word, aria-hidden; its opacity follows the progress",
             vars: { "--word-index" => "the word's position" }

        def initialize(text = nil, **options)
          super(**(text.nil? ? options : options.merge(text: text)))
        end

        def call
          content_tag(tag, **root_attributes) do
            safe_join([content_tag(:span, text, class: css(:reader)),
                       content_tag(:span, words, "aria-hidden" => "true")])
          end
        end

        def root_attributes
          attrs = { "style" => "--reveal-count: #{word_list.size}" }
          super(attrs)
        end

        private

        def word_list
          @word_list ||= text.to_s.split(/\s+/).reject(&:empty?)
        end

        # The words as spans, separated by plain spaces so the text wraps as text.
        def words
          safe_join(word_list.each_with_index.map do |word, index|
            content_tag(:span, word, "data-slot" => "text-reveal-word", "style" => "--word-index: #{index}")
          end, " ")
        end
      end
    end
  end
end
