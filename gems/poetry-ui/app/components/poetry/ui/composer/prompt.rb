# frozen_string_literal: true

module Poetry
  module Ui
    module Composer
      # A suggested prompt: a button elsewhere on the page that writes its
      # text into a composer and sends it. The chips under an empty
      # conversation, a quick reply, a "try again". The composer does the
      # writing and the sending through its own gate, so nothing goes
      # while a reply is running and a draft is never traded for a prompt
      # that could not go. submit: false only writes the text and puts the
      # caret after it, for a prompt the person finishes.
      # poetry_composer_prompt renders it; it is a Poetry Button, so it
      # takes a Button's variant: and size:. internal_component!: anatomy,
      # not a registered component.
      #
      # @api private
      class Prompt < Poetry::Core::Component
        internal_component!
        include PromptWiring

        option :composer, :string, required: true, doc: "The id of the composer the prompt is for."
        option :text, :string, required: true,
                               doc: "The text the prompt writes in place of the draft, and the button's label " \
                                    "unless a block gives one."
        option :submit, :boolean, default: true,
                                  doc: "Whether the composer sends the text at once. Off, the text is written and " \
                                       "the caret put after it."
        option :variant, :symbol, default: :outline, doc: "The Button variant the prompt renders at."
        option :size, :symbol, default: :sm, doc: "The Button size the prompt renders at."

        # Renders the prompt as a Button, labelled by the block or by its text.
        def call
          label = content.presence || text
          render(Button::Component.new(**button_options)) { label }
        end

        private

        # The composer's id, for the wiring.
        def prompt_composer = composer

        # The prompt's text, for the wiring.
        def prompt_text = text

        # Whether the press writes without sending.
        def prompt_writes_only? = !submit

        # The button's options: the prompt's wiring merged under the
        # caller's attributes, so a host's own data-action joins it.
        def button_options
          wiring = { data: { slot: "composer-prompt" } }.merge(stimulus_attributes_for(:prompt))

          { variant: variant, size: size }
            .merge(Poetry::Core::HTML::Attributes.merged(wiring, html_attributes))
            .symbolize_keys
        end
      end
    end
  end
end
