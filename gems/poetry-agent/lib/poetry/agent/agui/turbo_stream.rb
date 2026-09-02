# frozen_string_literal: true

require "cgi"

module Poetry
  module Agent
    module AGUI
      # Turbo Stream builders for the relay: plain strings, no view
      # context needed. `vreplace` is the versioned replace the runtime
      # installs on Turbo (`registerPoetryAgent`) - it applies a frame
      # only when its `data-version` is newer than the row's, so an
      # out-of-order delivery can never paint an older state over a
      # newer one.
      module TurboStream
        module_function

        # @param action [String] a Turbo Stream action (`append`, `replace`, `vreplace`, `remove`, ...)
        # @param target [String] the target element id
        # @param html [String, nil] the template content (already rendered, trusted)
        # @return [String]
        def build(action, target, html = nil)
          open = %(<turbo-stream action="#{escape(action)}" target="#{escape(target)}">)
          return "#{open}</turbo-stream>" if html.nil?

          "#{open}<template>#{html}</template></turbo-stream>"
        end

        # @param target [String]
        # @param html [String]
        # @return [String]
        def vreplace(target, html) = build("vreplace", target, html)

        # @param target [String]
        # @param html [String]
        # @return [String]
        def append(target, html) = build("append", target, html)

        # @param target [String]
        # @param html [String]
        # @return [String]
        def replace(target, html) = build("replace", target, html)

        # @param target [String]
        # @return [String]
        def remove(target) = build("remove", target)

        # One SSE frame carrying the streams (newlines folded, as Turbo's
        # stream source expects one `data:` line).
        #
        # @param html [String]
        # @return [String]
        def sse(html)
          "data: #{html.tr("\n", " ")}\n\n"
        end

        # @api private
        def escape(value)
          CGI.escapeHTML(value.to_s)
        end
      end
    end
  end
end
