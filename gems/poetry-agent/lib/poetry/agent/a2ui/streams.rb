# frozen_string_literal: true

require_relative "../agui/turbo_stream"

module Poetry
  module Agent
    module A2UI
      # Delivers a {Session}'s surfaces as Turbo Streams: a surface's first
      # appearance appends into the container (when one is given), every
      # later change is a versioned replace of its wrapper (`vreplace`,
      # from the AG-UI relay: a stale version never overwrites a newer
      # one), and a deletion removes it. The host renders each surface
      # through the `render` callable (typically a {Renderer}).
      #
      # @example
      #   streams = Streams.new(session: session, container: "surfaces",
      #                         render: ->(surface) { Renderer.new(surface, view: view_context).call })
      #   response.stream.write(AGUI::TurboStream.sse(streams.apply(message)))
      class Streams
        # @return [Session]
        attr_reader :session

        # @param session [Session]
        # @param render [#call] `(surface) -> html`
        # @param container [String, nil] the DOM id new surfaces append into
        def initialize(session:, render:, container: nil)
          @session = session
          @render = render
          @container = container
          @seen = {}
        end

        # Applies one message and returns the streams for what changed.
        #
        # @param message [Hash]
        # @return [String] Turbo Stream HTML (empty when nothing changed)
        def apply(message)
          streams(session.apply(message))
        end

        # @param messages [Array<Hash>]
        # @return [String] Turbo Stream HTML
        def apply_all(messages)
          streams(session.apply_all(messages))
        end

        # The streams for a set of surface ids.
        #
        # @param ids [Array<String>]
        # @return [String]
        def streams(ids)
          Array(ids).map { |id| stream_for(id) }.join
        end

        # @param id [String]
        # @return [String] the stream for one surface (remove, append, or vreplace)
        def stream_for(id)
          target = Renderer.element_id(id)
          surface = session.surface(id)
          return AGUI::TurboStream.remove(target) unless surface

          html = @render.call(surface)
          first = @container && !@seen[id]
          @seen[id] = true
          first ? AGUI::TurboStream.append(@container, html) : AGUI::TurboStream.vreplace(target, html)
        end

        # Marks surfaces as already on the page (rendered server-side), so
        # their next change replaces instead of appending.
        #
        # @param ids [Array<String>]
        # @return [void]
        def mark_seen(*ids)
          ids.flatten.each { |id| @seen[id] = true }
        end
      end
    end
  end
end
