# frozen_string_literal: true

module Poetry
  module Ui
    # Serves llms.txt / llms-full.txt generated live from the component
    # registry - the docs an LLM retrieves can never drift from the code.
    class LlmsController < ActionController::Base
      # GET /poetry/llms.txt - the catalog index.
      def index
        render plain: llms_text.index
      end

      # GET /poetry/llms-full.txt - the full per-component reference.
      def full
        render plain: llms_text.full
      end

      private

      def llms_text
        # The shared builder (the llms construction rule, extended): the
        # served text uses the exact registry construction the committed
        # file is generated from - helpers and blocks sections included.
        # The app's own components ride along (their section follows the
        # gem catalog), so an agent reading llms-full.txt sees their agent
        # rules and helpers too.
        Poetry::Core::LlmsText.new(registry: Poetry::Ui.registry,
                                   host_registry: Poetry::Core::HostComponents.registry(root: Rails.root))
      end
    end
  end
end
