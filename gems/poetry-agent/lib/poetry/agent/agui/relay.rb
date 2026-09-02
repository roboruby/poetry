# frozen_string_literal: true

require "json"

module Poetry
  module Agent
    module AGUI
      # Turns transcript changes into Turbo Streams. The host supplies the
      # row renderer (its own partial or component: a message and its
      # version in, the row's HTML out - the row must carry
      # `data-version`), the target id scheme, and the container new rows
      # append to. The relay stays view-free.
      #
      # Client tools ride the same channel: when a run ends with tool
      # calls the browser must execute, {#client_tool_streams} appends
      # one bridge element per call; the `poetry--agent--agui-client-tool`
      # controller executes it through the registrar and POSTs the result
      # to the continue URL, whose response streams the next run.
      #
      # @example Streaming a run into a page
      #   relay = Poetry::Agent::AGUI::Relay.new(transcript: transcript, container: "chat-messages",
      #                                          render: ->(message, version) { render_row(message, version) })
      #   client.run(input) { |event| relay.apply(event).each { |stream| write(TurboStream.sse(stream)) } }
      class Relay
        # The bridge controller's identifier.
        CLIENT_TOOL_CONTROLLER = "poetry--agent--agui-client-tool"

        # @return [Transcript]
        attr_reader :transcript

        # @param transcript [Transcript]
        # @param render [#call] `(message, version) -> String` the row HTML
        # @param container [String, nil] the id new rows append to (nil: replace only)
        # @param target [#call] `(message) -> String` the row's element id
        # @param action [String] the stream action for updates (`vreplace` by default)
        # @param append_render [#call, nil] `(message, version) -> String` the HTML a
        #   first appearance appends - the row inside its list wrapper (a scroller
        #   item); defaults to `render`
        def initialize(transcript:, render:, container: nil, target: ->(message) { "row-#{message.id}" },
                       action: "vreplace", append_render: nil)
          @transcript = transcript
          @render = render
          @append_render = append_render || render
          @container = container
          @target = target
          @action = action
          @seen = {}
        end

        # Applies an event and answers the Turbo Streams it produced: an
        # append for a message's first appearance (when a container is
        # set), then the update action for every change.
        #
        # @param event [Hash]
        # @return [Array<String>]
        def apply(event)
          @transcript.apply(event).filter_map { |id| stream_for(id) }
        end

        # Marks message ids the page already renders, so their next change
        # is an update rather than an append (server-rendered history).
        #
        # @param ids [Array<String>]
        # @return [self]
        def mark_seen(*ids)
          ids.flatten.each { |id| @seen[id.to_s] = true }
          self
        end

        # The stream for one message id (nil when the message is unknown).
        #
        # @param id [String]
        # @return [String, nil]
        def stream_for(id)
          message = @transcript.message(id)
          return nil unless message

          first = !@seen[id]
          @seen[id] = true
          return TurboStream.append(@container, @append_render.call(message, message.version)) if @container && first

          TurboStream.build(@action, @target.call(message), @render.call(message, message.version))
        end

        # Bridge elements for every pending client tool call.
        #
        # @param continue_url [String] where the browser POSTs `{ toolCallId, name, content, error }`
        # @param container [String] the element the bridge elements append to
        # @return [Array<String>]
        def client_tool_streams(continue_url:, container: @container)
          @transcript.pending_client_tools.map do |pending|
            call = { "toolCallId" => pending[:tool_call_id], "name" => pending[:name], "args" => pending[:input] || {} }
            id = TurboStream.escape(pending[:tool_call_id])
            element = "<div id=\"agui-client-tool-#{id}\" hidden data-controller=\"#{CLIENT_TOOL_CONTROLLER}\" " \
                      "data-#{CLIENT_TOOL_CONTROLLER}-call-value=\"#{TurboStream.escape(JSON.generate(call))}\" " \
                      "data-#{CLIENT_TOOL_CONTROLLER}-url-value=\"#{TurboStream.escape(continue_url)}\"></div>"
            TurboStream.append(container, element)
          end
        end
      end
    end
  end
end
