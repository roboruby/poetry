# frozen_string_literal: true

module Poetry
  module Ui
    module Composer
      # The Composer preview: the three states of the action slot, a draft,
      # the tools row, and the line-break posture. The send, the stop and
      # the redraw need a server; previews cover the markup each state
      # renders.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(id: "composer", url: "#", placeholder: "Ask anything", class: "max-w-xl")
        end

        # A draft the server rendered: the root drops data-empty and the
        # Send button reads at full strength.
        def with_draft
          render_component(id: "composer-draft", url: "#", class: "max-w-xl",
                           value: "Summarise the open pull requests and list the ones waiting on me.")
        end

        # A reply is running: the slot holds Stop, which names the hidden
        # Stop form. version: stamps the slot for a versioned replace.
        def running
          render_component(id: "composer-running", url: "#", stop_url: "#", status: :running, version: 3,
                           placeholder: "Ask anything", class: "max-w-xl")
        end

        # Stop was pressed and the reply has not ended yet.
        def stopping
          render_component(id: "composer-stopping", url: "#", stop_url: "#", status: :stopping, version: 4,
                           placeholder: "Ask anything", class: "max-w-xl")
        end

        def disabled
          render_component(id: "composer-disabled", url: "#", disabled: true,
                           placeholder: "This conversation is closed", class: "max-w-xl")
        end

        # Block content is the tools row beside Send.
        def with_tools
          render_with_template(template: "poetry/ui/composer/tools_preview")
        end

        # Enter breaks the line; Cmd/Ctrl+Enter sends.
        def line_breaks
          render_component(id: "composer-lines", url: "#", submit_on_enter: false, input_class: "min-h-24",
                           placeholder: "Write a longer note", class: "max-w-xl")
        end
      end
    end
  end
end
