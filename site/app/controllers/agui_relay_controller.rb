# frozen_string_literal: true

# The AG-UI relay demo: poetry-agent's Transcript + Relay turning the
# scripted agent's event stream into versioned Turbo Streams over SSE,
# the browser executing the agent's frontend tool call through the
# registrar and POSTing its result back (continue), and an interrupt
# answered as a URL decision. The whole state is the URL (?s=run&d=decision),
# so every point is shareable and every stream replays byte-identical.
class AguiRelayController < ApplicationController
  include ActionController::Live

  SOURCE_ID = "agui-relay-source"
  # The scroller's content element (MessageScroller renders "<id>-messages").
  SCROLLER_ID = "agui-relay-scroller-messages"
  NEXT_ID = "agui-relay-next"

  # GET: the current run's events as Turbo Streams over SSE.
  def stream
    response.headers["Content-Type"] = "text/event-stream"
    response.headers["X-Accel-Buffering"] = "no"
    response.headers["Last-Modified"] = Time.now.httpdate

    index = AguiReplay.cursor(params)
    decision = AguiReplay.decision(params)
    transcript = AguiReplay.transcript_before(index, decision: decision, tool_result: params[:tool_result].presence)
    relay = build_relay(transcript)
    relay.mark_seen(transcript.messages.map(&:id))

    AguiReplay.events(index, decision: decision).each do |event|
      pause(event["_sleep"])
      relay.apply(event.except("_sleep")).each { |html| write_stream(html) }
    end
    closing_streams(relay, index, decision).each { |html| write_stream(html) }
  ensure
    response.stream.close
  end

  # POST: the browser's client-tool result; answers with the resolved
  # row and the next run's stream source.
  def continue
    index = AguiReplay.cursor(params)
    body = JSON.parse(request.body.read.presence || "{}")
    transcript = AguiReplay.transcript_before(index + 1, tool_result: body["content"].presence)
    relay = build_relay(transcript)
    relay.mark_seen(transcript.messages.map(&:id))
    resolved = transcript.message("m1")
    streams = [
      relay.stream_for(resolved.id),
      Poetry::Agent::AGUI::TurboStream.remove(SOURCE_ID),
      Poetry::Agent::AGUI::TurboStream.append(NEXT_ID, source_tag(index + 1, tool_result: body["content"]))
    ].compact
    render body: streams.join, content_type: "text/vnd.turbo-stream.html"
  end

  private

  def build_relay(transcript)
    Poetry::Agent::AGUI::Relay.new(
      transcript: transcript, container: SCROLLER_ID,
      render: ->(message, version) { render_row(message, version) },
      append_render: ->(message, version) { render_item(message, version) }
    )
  end

  def render_row(message, version)
    render_to_string(partial: "agui_relay/row", locals: { message: message, version: version })
  end

  def render_item(message, version)
    render_to_string(partial: "agui_relay/item", locals: { message: message, version: version })
  end

  # After the last event: the client-tool bridge (run 1), the interrupt's
  # decision (run 2), or the replay link - and the stream source removed
  # so SSE does not reconnect and replay the run.
  def closing_streams(relay, index, decision)
    streams = [ Poetry::Agent::AGUI::TurboStream.remove(SOURCE_ID) ]
    streams.concat(relay.client_tool_streams(continue_url: agui_relay_continue_path(s: index, page: page_path)))
    controls = render_to_string(partial: "agui_relay/controls",
                                locals: { transcript: relay.transcript, index: index, decision: decision, page: page_path })
    streams << Poetry::Agent::AGUI::TurboStream.replace(NEXT_ID, controls)
  end

  def source_tag(index, tool_result: nil)
    src = agui_relay_stream_path(s: index, tool_result: tool_result.presence, instant: params[:instant].presence, page: page_path)
    %(<turbo-stream-source id="#{SOURCE_ID}" src="#{ERB::Util.html_escape(src)}"></turbo-stream-source>)
  end

  def write_stream(html)
    response.stream.write(Poetry::Agent::AGUI::TurboStream.sse(html))
  end

  def page_path
    page = params[:page].to_s
    page.match?(%r{\A/demos/agui-relay\z|\A/examples/demos/agui-relay/[a-z0-9_]+\z}) ? page : "/demos/agui-relay"
  end

  def pause(sleep_ms)
    return if sleep_ms.to_i.zero? || Rails.env.test? || params[:instant].present?

    sleep(sleep_ms / 1000.0)
  end
end
