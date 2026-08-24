# frozen_string_literal: true

module Poetry
  module Ui
    module ClipboardText
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(value: "gem install poetry-ui", label: "Install command")
        end

        # Display truncates, the clipboard gets the FULL value via
        # text_to_copy (the ported source's textToCopy contract).
        def truncated_copy
          render_component(value: "pk_live_51Nx…9fQ2", label: "API key",
                           text_to_copy: "pk_live_51NxAbCdEfGhIjKlMnOpQrStUvWxYz0123456789fQ2")
        end

        def disabled
          render_component(value: "rotated-out-key", label: "API key", disabled: true)
        end
      end
    end
  end
end
