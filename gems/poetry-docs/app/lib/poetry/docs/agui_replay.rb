# frozen_string_literal: true

# The docs site's scripted AG-UI agent: three runs of real AG-UI events
# (text deltas, reasoning, a backend tool call with its result, shared
# state, a frontend tool call the browser executes, an interrupt the
# person answers), replayed through poetry-agent's relay into the chat
# components. Deterministic and keyless: the runs are data, the browser
# executes the client tool for real, and the decision is a URL param.
#
# The runs are conformant AG-UI 1.0 producer output: each RUN_STARTED
# declares the protocol version, and the reasoning is a message of its own.
#
# Run 1 answers the user's question and calls the page's tab tool, which
# asks the person first. Run 2 (after the browser reports the tool result,
# or the decline) continues and pauses on an approval interrupt. Run 3
# depends on the decision: a billing subagent starts the trial.
module Poetry
  module Docs
    class AguiReplay
      THREAD_ID = "docs-agui-relay"
      CLIENT_TOOL = "poetry.sections.set_value"
      # The tool_result a declined tab switch rides the URL as.
      DECLINED = "declined"
      USER_TEXT = "Which plan fits a 10-person team? Show me the pricing tab."
      # The subagent that starts the trial in run 3.
      BILLING = "s-billing"

      APPROVAL = { "id" => "int-trial", "reason" => "approval",
                   "message" => "Start a 30-day Team trial for the workspace?" }.freeze

      class << self
        # The plans app's real result for a team of ten (text for the model, the
        # plans as data, the table as a fragment), the same bytes every run.
        #
        # @return [Hash] the CallToolResult, string keys
        def plans_app_result
          JSON.parse(JSON.generate(McpAppShowcase.plans_result(team_size: 10).to_response.to_h))
        end

        # The events of one run.
        #
        # @param index [Integer] 1 to 4
        # @param decision [Boolean, nil] the approval answer (run 3)
        # @param email [String, nil] the reminder email the trial surface posted (run 4)
        # @return [Array<Hash>] AG-UI events; `_sleep` is docs pacing, not protocol
        def events(index, decision: nil, email: nil)
          case index
          when 1 then run_one
          when 2 then run_two
          when 3 then run_three(decision)
          else run_four(email)
          end
        end

        # The A2UI surface the agent paints in run 3 (the a2ui-middleware
        # shape: an `a2ui-surface` activity whose content carries the
        # envelope messages): the trial card with a reminder form.
        #
        # @return [Array<Hash>]
        def trial_surface
          [ { "version" => "1.0",
              "createSurface" => {
                "surfaceId" => "trial", "catalogId" => Poetry::Agent::A2UI::Catalogs::Basic::ID, "sendDataModel" => true,
                "dataModel" => { "email" => "" },
                "components" => [
                  { "id" => "root", "component" => "Column", "children" => %w[title note email remind] },
                  { "id" => "title", "component" => "Text", "text" => "### Trial TR-3041 is live" },
                  { "id" => "note", "component" => "Text", "variant" => "caption",
                    "text" => "Ends in 30 days. Want a reminder three days before?" },
                  { "id" => "email", "component" => "TextField", "label" => "Reminder email", "value" => { "@path" => "/email" },
                    "placeholder" => "you@example.com",
                    "checks" => [ { "condition" => { "@call" => "email", "args" => { "value" => { "@path" => "/email" } } },
                                   "message" => "Enter a valid email" } ] },
                  { "id" => "remind", "component" => "Button", "child" => "remind_label", "variant" => "primary",
                    "action" => { "event" => { "name" => "set_reminder", "context" => { "email" => { "@path" => "/email" } } } },
                    "checks" => [ { "condition" => { "@call" => "required", "args" => { "value" => { "@path" => "/email" } } },
                                   "message" => "Add the email first" } ] },
                  { "id" => "remind_label", "component" => "Text", "text" => "Set reminder" }
                ]
              } } ]
        end

        # The A2UI session holding every surface the transcript's activities
        # painted (the relay's own consumer of the a2ui-middleware path).
        #
        # @param transcript [Poetry::Agent::AGUI::Transcript]
        # @return [Poetry::Agent::A2UI::Session]
        def surface_session(transcript)
          session = Poetry::Agent::A2UI::Session.new
          transcript.messages.each do |message|
            message.parts.each do |part|
              session.apply_activity(part[:content]) if part[:kind] == :activity && part[:activity_type] == "a2ui-surface"
            end
          end
          session
        end

        # The user message every run's input starts from.
        #
        # @return [Hash]
        def user_message
          Poetry::Agent::AGUI::RunInput.user_message(USER_TEXT, id: "u1")
        end

        # The frontend tools the page advertises to the agent (the tabs
        # component's declared tools, named as the registrar registers them).
        #
        # @return [Array<Hash>]
        def client_tools
          definitions = Poetry::Ui::Tabs::Component.tool_definitions
          definitions.map { |definition| Poetry::Agent::AGUI.tool_descriptor("sections", definition) }
        end

        # The run index a request is on, clamped.
        #
        # @param params [ActionController::Parameters]
        # @return [Integer]
        def cursor(params)
          params.fetch(:s, 1).to_i.clamp(1, 4)
        end

        # The approval decision carried by the request, if any.
        #
        # @param params [ActionController::Parameters]
        # @return [Boolean, nil]
        def decision(params)
          { "1" => true, "0" => false }[params[:d].to_s]
        end

        # A transcript with every run before `index` applied (instantly),
        # the client tool resolved with the browser's result when given, or
        # declined when the person said no. The tab tool asks first.
        #
        # @param index [Integer]
        # @param decision [Boolean, nil]
        # @param tool_result [String, nil]
        # @param email [String, nil]
        # @return [Poetry::Agent::AGUI::Transcript]
        def transcript_before(index, decision: nil, tool_result: nil, email: nil)
          transcript = Poetry::Agent::AGUI::Transcript.new(client_tools: [ { name: CLIENT_TOOL, confirm: true } ])
          transcript.add_message(user_message)
          (1...index).each do |run|
            # Each run through its own pipeline, as the stream action does: the
            # transcript reduces verified events.
            pipeline = Poetry::Agent::AGUI::Pipeline.new
            events(run, decision: decision, email: email).each do |event|
              pipeline.push(event.except("_sleep")).each { |verified| transcript.apply(verified) }
            end
            next unless run == 1

            if tool_result == DECLINED
              transcript.decline_client_tool("c-tab")
            else
              transcript.resolve_client_tool("c-tab", tool_result || '{"value":"pricing","changed":true}')
            end
          end
          transcript
        end

        private

        def run_one
          [
            run_started("r1"),
            *reasoning("m1-thinking", "The team size points at the Team plan; the plans tool has the current numbers."),
            *text("m1", "For a 10-person team the Team plan fits: per-seat pricing with the admin controls included. "),
            tool_start("c-plans", "lookup_plans", "m1"),
            { "type" => "TOOL_CALL_ARGS", "toolCallId" => "c-plans", "delta" => '{"seats":10}', "_sleep" => 250 },
            { "type" => "TOOL_CALL_END", "toolCallId" => "c-plans" },
            { "type" => "TOOL_CALL_RESULT", "messageId" => "t-plans", "toolCallId" => "c-plans",
              "content" => '{"plans":[{"name":"Team","seat_price":12,"min_seats":5},{"name":"Business","seat_price":24,"min_seats":25}]}',
              "_sleep" => 700 },
            # The plans tool has an app (the MCP App demo's plan picker), which
            # AG-UI's MCP Apps middleware sends as an activity after the result;
            # with no host to show it, the relay's fallback step shows the text.
            { "type" => "ACTIVITY_SNAPSHOT", "messageId" => "a1", "activityType" => Poetry::Agent::Apps::Activity::TYPE,
              "content" => { "result" => plans_app_result, "resourceUri" => "ui://poetry-docs/plans", "serverId" => "poetry-docs",
                             "serverHash" => "5b2f0d9c4e7a1b8d3f6c2a9e0d4b7c15", "toolInput" => { "team_size" => 10 } },
              "replace" => true, "_sleep" => 300 },
            { "type" => "STATE_SNAPSHOT", "snapshot" => { "recommended" => "Team", "seats" => 10 } },
            { "type" => "STATE_DELTA", "delta" => [ { "op" => "add", "path" => "/monthly", "value" => 120 } ] },
            *text("m1", "Team is $12 a seat, so $120 a month for ten. I'll switch you to the pricing tab."),
            tool_start("c-tab", CLIENT_TOOL, "m1"),
            { "type" => "TOOL_CALL_ARGS", "toolCallId" => "c-tab", "delta" => '{"value":"pricing"}', "_sleep" => 200 },
            { "type" => "TOOL_CALL_END", "toolCallId" => "c-tab" },
            run_finished("r1")
          ]
        end

        def run_two
          [
            run_started("r2"),
            *text("m2", "The Team plan comes with a 30-day trial - want me to start one?"),
            { "type" => "RUN_FINISHED", "threadId" => THREAD_ID, "runId" => "r2",
              "outcome" => { "type" => "interrupt", "interrupts" => [ APPROVAL ] } }
          ]
        end

        def run_three(decision)
          if decision
            [
              run_started("r3"),
              # The billing subagent starts the trial: its call and result carry its
              # subagentRunId, so the page nests them under a step naming it.
              { "type" => "SUBAGENT_STARTED", "subagentRunId" => BILLING, "name" => "billing",
                "description" => "Starts trials and keeps the invoices", "_sleep" => 200 },
              tool_start("c-trial", "start_trial", "m3-billing").merge("subagentRunId" => BILLING),
              { "type" => "TOOL_CALL_ARGS", "toolCallId" => "c-trial", "delta" => '{"plan":"Team","days":30}', "_sleep" => 200 },
              { "type" => "TOOL_CALL_END", "toolCallId" => "c-trial" },
              { "type" => "TOOL_CALL_RESULT", "messageId" => "t-trial", "toolCallId" => "c-trial", "subagentRunId" => BILLING,
                "content" => '{"trial":"TR-3041","ends":"in 30 days"}', "_sleep" => 700 },
              { "type" => "SUBAGENT_FINISHED", "subagentRunId" => BILLING, "result" => { "trial" => "TR-3041" } },
              *text("m3", "Trial TR-3041 is live for 30 days on the Team plan. Nothing is billed until it ends."),
              { "type" => "ACTIVITY_SNAPSHOT", "messageId" => "a3", "activityType" => "a2ui-surface",
                "content" => { "a2ui_operations" => trial_surface }, "_sleep" => 300 },
              run_finished("r3")
            ]
          else
            [
              run_started("r3"),
              *text("m3", "No trial started. The pricing tab stays open whenever you want to compare again."),
              run_finished("r3")
            ]
          end
        end

        def run_four(email)
          [
            run_started("r4"),
            *text("m4", "Reminder set for #{email.presence || "you"}, three days before the trial ends. " \
                        "The surface's action reached this run as forwardedProps.a2uiAction - the way A2UI rides AG-UI."),
            run_finished("r4")
          ]
        end

        # Declares the protocol version, as a 1.0 producer must.
        def run_started(run_id)
          { "type" => "RUN_STARTED", "threadId" => THREAD_ID, "runId" => run_id,
            "protocolVersion" => Poetry::Agent::AGUI::PROTOCOL_VERSION }
        end

        def run_finished(run_id)
          { "type" => "RUN_FINISHED", "threadId" => THREAD_ID, "runId" => run_id }
        end

        def tool_start(id, name, message_id)
          { "type" => "TOOL_CALL_START", "toolCallId" => id, "toolCallName" => name, "parentMessageId" => message_id, "_sleep" => 300 }
        end

        # A reasoning message of its own (role reasoning, its own id), streamed word by word.
        def reasoning(message_id, sentence)
          [ { "type" => "REASONING_MESSAGE_START", "messageId" => message_id, "role" => "reasoning" } ] +
            chunks(sentence).map { |chunk| { "type" => "REASONING_MESSAGE_CONTENT", "messageId" => message_id, "delta" => chunk, "_sleep" => 40 } } +
            [ { "type" => "REASONING_MESSAGE_END", "messageId" => message_id } ]
        end

        def text(message_id, sentence)
          [ { "type" => "TEXT_MESSAGE_START", "messageId" => message_id, "role" => "assistant" } ] +
            chunks(sentence).map { |chunk| { "type" => "TEXT_MESSAGE_CONTENT", "messageId" => message_id, "delta" => chunk, "_sleep" => 35 } } +
            [ { "type" => "TEXT_MESSAGE_END", "messageId" => message_id } ]
        end

        # Word-paced deltas, keeping the trailing space that separates them.
        def chunks(sentence)
          sentence.scan(/\S+\s*/).each_slice(3).map(&:join)
        end
      end
    end
  end
end
