# frozen_string_literal: true

module Poetry
  module Ui
    # Serves llms.txt / llms-full.txt generated live from the component
    # registry - the docs an LLM retrieves can never drift from the code.
    class LlmsController < ActionController::Base
      def index
        render plain: llms_text.index
      end

      def full
        render plain: llms_text.full
      end

      private

      def llms_text
        # The shared builder ('s construction rule, extended): the
        # served text uses the exact registry construction the committed
        # file is generated from - helpers and blocks sections included.
        Poetry::Core::LlmsText.new(registry: Poetry::Ui.registry)
      end
    end
  end
end
