# frozen_string_literal: true

module Poetry
  module Ui
    module Composer
      # A suggested prompt's wiring, declared once for the two classes that
      # need it: the composer, whose contract and registry project it, and
      # the prompt, which renders it on a button of its own elsewhere on
      # the page.
      #
      # @api private
      module PromptWiring
        extend ActiveSupport::Concern

        included do
          # The press hands the text to the composer the prompt names; the
          # composer writes it and sends it through its own gate.
          use_stimulus do
            on :prompt do
              controller :composer_prompt do
                register
                value :composer, from: :prompt_composer
                value :text, from: :prompt_text
                value :send, false, if: :prompt_writes_only?
                action :write, on: :click
              end
            end
          end
        end
      end
    end
  end
end
