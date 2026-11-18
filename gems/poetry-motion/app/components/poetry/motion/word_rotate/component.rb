# frozen_string_literal: true

module Poetry
  module Motion
    module WordRotate
      # A word that turns over into the next, in place: "Build faster",
      # "Build safer". The words are server-rendered and stacked in one cell
      # sized to the longest, so the line never reflows; the first shows,
      # and a screen reader hears only it. Hover and focus pause it, and it
      # stops after its rounds, back on the first word.
      #
      # @example
      #   Build <%= poetry_word_rotate(words: %w[faster safer together]) %>
      class Component < Poetry::Core::Component
        include Poetry::Motion::Options

        AGENT_RULES = [
          "The first word is the one that counts: it is what renders, what a screen reader hears and " \
          "where the rotation stops. Order the words so the sentence reads right with only it.",
          "Keep rounds: small. A rotation that runs past five seconds is auto-updating content and " \
          "needs a way to stop it (WCAG 2.2.2); rounds: 0 never stops."
        ].freeze

        use_stimulus do
          on :root do
            controller :word_rotate, if: :animate do
              register
              value :interval
              value :rounds
            end
          end
          on :word do
            controller(:word_rotate, if: :animate) { target :word }
          end
        end

        motion_options
        option :words, :list, required: true, doc: "The words, the first one first."
        option :interval, :integer, default: 2500, doc: "Milliseconds each word shows."
        option :rounds, :integer, default: 1, doc: "How many times it goes through the words; 0 keeps going."

        part "word-rotate", "The cell the words share, sized to the longest"
        part "word-rotate-word", "One word; the active one shows",
             states: { "data-active" => "the word showing" }

        def before_render
          raise ArgumentError, "word_rotate needs at least two words:" if Array(words).size < 2

          ensure_within!(:interval, 500..20_000)
          ensure_within!(:rounds, 0..20)
        end

        def call
          tag.span(**root_attributes) do
            stack = Array(words).each_with_index.map do |word, index|
              attrs = { "data-slot" => "word-rotate-word", class: css(:word), **stimulus_attributes_for(:word) }
              attrs["data-active"] = "" if index.zero?
              content_tag(:span, word, **attrs)
            end
            safe_join([content_tag(:span, Array(words).first, class: css(:reader)),
                       content_tag(:span, safe_join(stack), "aria-hidden" => "true", class: css(:stack))])
          end
        end
      end
    end
  end
end
