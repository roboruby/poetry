# frozen_string_literal: true

# The A2UI surface demo: poetry-agent's Session + Renderer + Streams. The
# stream action replays a scripted agent's messages (a surface created,
# its components, its data) as versioned Turbo Streams over SSE; the
# action endpoint turns a submitted surface form into the spec's
# renderer-to-agent `action` message and answers with the scripted
# agent's reply, rendered and delivered the same way.
class A2uiSurfaceController < ApplicationController
  include ActionController::Live

  STAGE_ID = "a2ui-stage"
  SOURCE_ID = "a2ui-surface-source"
  LOG_ID = "a2ui-action-log"

  # GET: the order surface, streamed progressively.
  def stream
    response.headers["Content-Type"] = "text/event-stream"
    response.headers["X-Accel-Buffering"] = "no"
    response.headers["Last-Modified"] = Time.now.httpdate

    session = Poetry::Agent::A2UI::Session.new
    streams = Poetry::Agent::A2UI::Streams.new(session: session, container: STAGE_ID,
                                               render: ->(surface) { render_surface(surface) })
    A2uiShowcase::STREAM.each do |message|
      pause(message["_sleep"])
      html = streams.apply(message.except("_sleep"))
      write_stream(html) unless html.empty?
    end
    write_stream(Poetry::Agent::AGUI::TurboStream.remove(SOURCE_ID))
  ensure
    response.stream.close
  end

  # POST: a submitted surface form. The bound values sync into the data
  # model, the surface's checks run against it, the source component's
  # event becomes the action message, and the scripted agent's reply
  # streams back with the message itself. A failing check re-renders the
  # surface with its errors instead.
  def action
    payload = params[:a2ui].respond_to?(:permit!) ? params[:a2ui].permit!.to_h : {}
    session = A2uiShowcase.session
    action = session.action(surface_id: payload["surface"].to_s, source: payload["action"].to_s,
                            values: payload["values"] || {})
    errors = action&.errors || {}
    streams = Poetry::Agent::A2UI::Streams.new(session: session,
                                               render: ->(surface) { render_surface(surface, form: true, errors: errors) })
    streams.mark_seen(*session.surfaces.keys)
    html = if action&.valid? then streams.apply_all(A2uiShowcase.reply(action))
    elsif action then streams.stream_for(action.surface.id)
    else ""
    end
    log = render_to_string(partial: "a2ui_surface/log", locals: { action: action, rejected: true })
    html += Poetry::Agent::AGUI::TurboStream.replace(LOG_ID, log)
    render body: html, content_type: "text/vnd.turbo-stream.html", status: action&.valid? ? :ok : :unprocessable_entity
  end

  private

  def render_surface(surface, form: false, errors: {})
    Poetry::Agent::A2UI::Renderer.new(surface, view: view_context, errors: errors,
                                      action_url: form ? a2ui_surface_action_path : nil).call
  end

  def write_stream(html)
    response.stream.write(Poetry::Agent::AGUI::TurboStream.sse(html))
  end

  def pause(sleep_ms)
    return if sleep_ms.to_i.zero? || Rails.env.test? || params[:instant].present?

    sleep(sleep_ms / 1000.0)
  end
end
