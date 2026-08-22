# frozen_string_literal: true

# The docs site's scripted conversation for the Chat Replay demo (the
# rig's reference consumer). One script, addressed by segment
# index via params - fully deterministic, so any state is a shareable URL
# and every stream replays byte-identical.
class ChatReplay
  class << self
    def script
      @script ||= Poetry::Ui::Chat.script do
        user "What's the weather looking like in Tokyo this weekend?"
        assistant do |w|
          w.reasoning "Weekend forecast - the weather tool has this.", delay_ms: 40
          w.tool("getWeather", input: { city: "Tokyo", days: 2 }, sleep_ms: 900,
                 output: { saturday: "clear, 21°C", sunday: "light rain, 18°C" })
          w.text "Saturday looks perfect - clear and 21°C. Sunday turns to light rain, " \
                 "so plan the outdoor things for Saturday.", delay_ms: 35
        end
        user "Then book the rooftop dinner for Saturday."
        assistant do |w|
          w.text "Reserving the rooftop for Saturday evening books under your name " \
                 "and takes a cancellation fee after 6pm - approve?", delay_ms: 35
          w.tool("bookDinner", input: { venue: "rooftop", day: "saturday", seats: 2 },
                 approval: true, sleep_ms: 700,
                 output: { confirmation: "RT-204", time: "19:30" })
          w.text "Done - table for two at 19:30, confirmation RT-204. " \
                 "Enjoy the clear skies.", delay_ms: 35
        end
      end
    end

    def segments = script.segments

    # The segment currently streaming, clamped to the script.
    def cursor(params)
      params.fetch(:s, 1).to_i.clamp(1, segments.length - 1)
    end

    def decision(params)
      { "1" => true, "0" => false }[params[:a].to_s]
    end
  end
end
