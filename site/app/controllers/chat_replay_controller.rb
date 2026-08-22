# frozen_string_literal: true

# The Chat Replay stream: Poetry::Ui::Chat frames delivered as REAL Turbo
# Streams over SSE (<turbo-stream-source>), each frame a versioned
# `vreplace` of the same message row - the MessageScroller streaming
# contract ("stream by UPDATING a row's text"), demonstrated live. The
# whole stream derives from params, so replays are byte-identical;
# `instant=1` (and the test env) drops the sleeps.
class ChatReplayController < ApplicationController
  include ActionController::Live

  def stream
    response.headers["Content-Type"] = "text/event-stream"
    response.headers["X-Accel-Buffering"] = "no"
    response.headers["Last-Modified"] = Time.now.httpdate

    seg = ChatReplay.segments[ChatReplay.cursor(params)]
    decision = ChatReplay.decision(params)
    frames = decision.nil? ? seg.frames : seg.continuation_frames(approved: decision)

    frames.each do |frame|
      pause(frame.sleep_ms)
      write_stream(render_frame(seg, frame))
    end
    write_stream(closing_streams(seg, decision))
  ensure
    response.stream.close
  end

  private

  def render_frame(seg, frame)
    row = render_to_string(partial: "chat_replay/row",
                           locals: { seg_id: seg.id, parts: frame.parts, version: frame.version })
    %(<turbo-stream action="vreplace" target="row-#{seg.id}"><template>#{row}</template></turbo-stream>)
  end

  # After the last frame: swap the stream source out (no SSE reconnect
  # replay) and reveal the next step - Send, the approval buttons, or
  # the replay link.
  def closing_streams(seg, decision)
    controls = render_to_string(partial: "chat_replay/controls",
                                locals: { seg: seg, decision: decision, page: page_path })
    # Removing the source is load-bearing: SSE auto-reconnects after the
    # server closes, and a reconnect would replay the whole stream.
    %(<turbo-stream action="remove" target="chat-replay-source"></turbo-stream>) +
      %(<turbo-stream action="replace" target="chat-replay-next"><template>#{controls}</template></turbo-stream>)
  end

  def write_stream(html)
    response.stream.write("data: #{html.gsub("\n", ' ')}\n\n")
  end

  # The consuming page (docs demo or a standalone example view) - control
  # links must target IT, not this stream endpoint. Allowlisted.
  def page_path
    page = params[:page].to_s
    page.match?(%r{\A/demos/chat-replay\z|\A/examples/demos/chat-replay/[a-z0-9_]+\z}) ? page : "/demos/chat-replay"
  end

  def pause(sleep_ms)
    return if sleep_ms.to_i.zero? || Rails.env.test? || params[:instant].present?

    sleep(sleep_ms / 1000.0)
  end
end
