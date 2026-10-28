# frozen_string_literal: true

require "json"

# How the docs relays render an assistant turn's agent activity, after
# shadcn@4.23.0's Trace chat example: a run of reasoning and tool parts is
# one Trace, a text part ends the run, and a tool waiting on a person is a
# prompt (an Item in the relay's controls), not activity. Reasoning reads
# "Thinking" while it streams and "Thought" once it closes. Each tool the
# scripted agents call has its own glyph and words per state; any other
# tool reads "Running <name>", "Ran <name>", "Failed to run <name>".
#
# @example The runs of one assistant message
#   AgentActivity.runs(message.parts).map(&:kind) # => [:activity, :text, :activity]
module Poetry
  module Docs
    module AgentActivity
      # One run of an assistant turn: :text (its text), :activity (reasoning
      # and tool parts for one Trace), :approval (a tool waiting on a person;
      # the relay's controls ask), or :part (anything else, an activity the
      # relay renders itself).
      Run = Struct.new(:kind, :text, :parts, :part, keyword_init: true)

      # A Trace step's arguments for one part, and the detail its disclosure
      # shows: `{ kind: :reasoning, text: }`, `{ kind: :io, input:, output:,
      # output_language: }`, `{ kind: :error, text: }`, or nil for a line.
      Step = Struct.new(:title, :icon, :status, :description, :open, :detail, keyword_init: true)

      # One tool's glyph and words: doing, done, failed and denied, the
      # approval prompt's ask, and how its output reads.
      Tool = Struct.new(:icon, :running, :done, :failed, :denied, :ask, :ask_detail, :output, keyword_init: true)

      module_function

      # The parts grouped as upstream's chat example groups them: adjacent
      # reasoning and tool parts share a run, a text part or a pending
      # approval ends it, and adjacent text parts join.
      #
      # @param parts [Array<Hash>] Chat-shaped parts
      # @return [Array<Run>]
      def runs(parts)
        parts.each_with_object([]) do |part, runs|
          last = runs.last
          case part[:kind]
          when :text
            if last&.kind == :text
              last.text += part[:text].to_s
            elsif part[:text].to_s.strip.present?
              runs << Run.new(kind: :text, text: part[:text].to_s)
            end
          when :tool
            if part[:state] == :awaiting_approval
              runs << Run.new(kind: :approval, part: part)
            else
              activity(runs, part)
            end
          when :reasoning then activity(runs, part)
          else runs << Run.new(kind: :part, part: part)
          end
        end
      end

      # The step for a reasoning or tool part.
      #
      # @param part [Hash]
      # @return [Step]
      def step(part)
        part[:kind] == :reasoning ? reasoning_step(part) : tool_step(part)
      end

      # The approval prompt for a tool waiting on a person.
      #
      # @param part [Hash] a tool part in :awaiting_approval
      # @return [Hash] `icon:`, `title:`, `description:` for the approval partial
      def approval(part)
        tool = tool(part[:name], part[:input])
        { icon: tool.icon, title: tool.ask, description: tool.ask_detail }
      end

      # The glyph and words for a tool call, read off its input.
      #
      # @param name [String]
      # @param input [Hash, nil]
      # @return [Tool]
      def tool(name, input)
        input = stringify(input.is_a?(Hash) ? input : {})
        case name
        when "lookup_plans" then lookup_plans(input)
        when "poetry.sections.set_value" then set_section(input)
        when "start_trial" then start_trial(input)
        when "getWeather" then weather(input)
        when "bookDinner" then book_dinner(input)
        else build(:wrench, "Running #{name}", "Ran #{name}", "Failed to run #{name}", ask: "Run #{name}?")
        end
      end

      # Starts a run with the part, or joins the run before it.
      def activity(runs, part)
        if runs.last&.kind == :activity
          runs.last.parts << part
        else
          runs << Run.new(kind: :activity, parts: [ part ])
        end
      end

      # Reasoning: open and shimmering while it streams, a closed disclosure after.
      def reasoning_step(part)
        running = part[:state] == :streaming
        text = part[:text].to_s.strip
        Step.new(title: running ? "Thinking" : "Thought", icon: :brain, status: (:running if running),
                 open: running, detail: (text.empty? ? nil : { kind: :reasoning, text: text }))
      end

      # A tool call: its state picks the words and the status; a finished
      # call discloses its input and output, a failed one its error.
      def tool_step(part)
        tool = tool(part[:name], part[:input])
        case part[:state]
        when :loading then Step.new(title: tool.running, icon: tool.icon, status: :running)
        when :awaiting_client
          Step.new(title: tool.running, icon: tool.icon, status: :pending, description: "in the browser")
        when :denied then Step.new(title: tool.denied, icon: tool.icon)
        when :error
          Step.new(title: tool.failed, icon: tool.icon, status: :error,
                   detail: { kind: :error, text: error_text(part[:output]) })
        else
          output = tool.output&.call(stringify(part[:output]))
          Step.new(title: tool.done, icon: tool.icon,
                   detail: { kind: :io, input: JSON.generate(part[:input] || {}),
                             output: output || JSON.generate(part[:output]), output_language: output ? "text" : "json" })
        end
      end

      def lookup_plans(input)
        plans = input["seats"] ? "plans for #{input["seats"]} seats" : "plans"
        build(:search, "Looking up #{plans}", "Looked up #{plans}", "Couldn't look up #{plans}",
              output: lambda { |out|
                Array(out["plans"]).map do |plan|
                  "#{plan["name"]}: $#{plan["seat_price"]} a seat, #{plan["min_seats"]}+ seats"
                end.join("\n").presence
              })
      end

      def set_section(input)
        tab = input["value"] ? "the #{input["value"]} tab" : "a tab"
        build(:"panel-top", "Switching to #{tab}", "Switched to #{tab}", "Couldn't switch to #{tab}")
      end

      def start_trial(input)
        trial = [ input["days"] && "#{input["days"]}-day", input["plan"], "trial" ].compact.join(" ")
        build(:"calendar-check", "Starting a #{trial}", "Started a #{trial}", "Couldn't start the #{trial}",
              output: ->(out) { "#{out["trial"]}, ends #{out["ends"]}" if out["trial"] })
      end

      def weather(input)
        place = input["city"] ? " for #{input["city"]}" : ""
        build(:sun, "Getting the weather#{place}", "Got the weather#{place}", "Couldn't get the weather#{place}",
              output: ->(out) { out.map { |day, forecast| "#{day.capitalize}: #{forecast}" }.join("\n").presence })
      end

      def book_dinner(input)
        table = [ input["venue"] && "the #{input["venue"]}", input["day"] && "for #{input["day"].capitalize}" ]
                .compact.join(" ").presence || "a table"
        build(:utensils, "Booking #{table}", "Booked #{table}", "Couldn't book #{table}",
              denied: "Denied booking #{table}", ask: "Book #{table}?",
              ask_detail: "A table for #{input["seats"] || 2} under your name; a cancellation fee applies after 6pm.",
              output: ->(out) { "#{out["confirmation"]} at #{out["time"]}" if out["confirmation"] })
      end

      # A Tool from its words; denied defaults to upstream's "Denied: <doing>".
      def build(icon, running, done, failed, denied: nil, ask: nil, ask_detail: nil, output: nil)
        Tool.new(icon: icon, running: running, done: done, failed: failed, denied: denied || "Denied: #{running}",
                 ask: ask || "#{running}?", ask_detail: ask_detail, output: output)
      end

      # A failed call's error as text.
      def error_text(output)
        output = stringify(output)
        return output["error"].to_s if output.is_a?(Hash) && output["error"]

        output.is_a?(String) ? output : JSON.generate(output)
      end

      # A value with string keys all the way down (the Chat DSL scripts
      # symbol keys, AG-UI parses strings).
      def stringify(value)
        case value
        when Hash then value.to_h { |key, inner| [ key.to_s, stringify(inner) ] }
        when Array then value.map { |inner| stringify(inner) }
        else value
        end
      end

      private_class_method :activity, :reasoning_step, :tool_step, :lookup_plans, :set_section, :start_trial,
                           :weather, :book_dinner, :build, :error_text, :stringify
    end
  end
end
