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
    email = params[:email].presence
    transcript = AguiReplay.transcript_before(index, decision: decision, tool_result: params[:tool_result].presence,
                                                     email: email)
    relay = build_relay(transcript)
    relay.mark_seen(transcript.messages.map(&:id))

    AguiReplay.events(index, decision: decision, email: email).each do |event|
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

  # POST: the trial surface's form (A2UI over AG-UI). The bound values and
  # the source component become the spec's action message; a failing
  # check re-renders the surface's row with the failures, a passing one
  # points the page at run 4, which receives the action as forwardedProps.
  def surface
    transcript = AguiReplay.transcript_before(4, decision: true, tool_result: params[:tool_result].presence)
    session = AguiReplay.surface_session(transcript)
    payload = params[:a2ui].respond_to?(:permit!) ? params[:a2ui].permit!.to_h : {}
    action = session.action(surface_id: payload["surface"].to_s, source: payload["action"].to_s,
                            values: payload["values"] || {})
    relay = build_relay(transcript)
    relay.mark_seen(transcript.messages.map(&:id))
    row = transcript.message("a3")
    if action&.valid?
      email = action.to_h.dig("action", "context", "email")
      streams = [ Poetry::Agent::AGUI::TurboStream.remove(SOURCE_ID),
                  Poetry::Agent::AGUI::TurboStream.append(NEXT_ID, source_tag(4, email: email)) ]
      render body: streams.join, content_type: "text/vnd.turbo-stream.html"
    else
      html = render_row(row, row.version, surface_errors: action&.errors || {})
      render body: Poetry::Agent::AGUI::TurboStream.vreplace("row-#{row.id}", html, morph: true),
             content_type: "text/vnd.turbo-stream.html", status: :unprocessable_entity
    end
  end

  private

  def build_relay(transcript)
    Poetry::Agent::AGUI::Relay.new(
      transcript: transcript, container: SCROLLER_ID, morph: true,
      render: ->(message, version) { render_row(message, version) },
      append_render: ->(message, version) { render_item(message, version) }
    )
  end

  def render_row(message, version, surface_errors: {})
    render_to_string(partial: "agui_relay/row",
                     locals: { message: message, version: version, surface_errors: surface_errors })
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

  def source_tag(index, tool_result: nil, email: nil)
    src = agui_relay_stream_path(s: index, tool_result: tool_result.presence, email: email.presence,
                                 instant: params[:instant].presence, page: page_path)
    %(<turbo-stream-source id="#{SOURCE_ID}" src="#{ERB::Util.html_escape(src)}"></turbo-stream-source>)
  end

  # The surface form posts here; the page and pacing ride the query.
  def surface_url
    agui_relay_surface_path(instant: params[:instant].presence, page: page_path)
  end
  helper_method :surface_url

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
