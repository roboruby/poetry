# frozen_string_literal: true

# The docs site's scripted AG-UI agent: three runs of real AG-UI events
# (text deltas, reasoning, a backend tool call with its result, shared
# state, a frontend tool call the browser executes, an interrupt the
# person answers), replayed through poetry-agent's relay into the chat
# components. Deterministic and keyless: the runs are data, the browser
# executes the client tool for real, and the decision is a URL param.
#
# Run 1 answers the user's question and calls the page's tab tool. Run 2
# (after the browser reports the tool result) continues and pauses on an
# approval interrupt. Run 3 depends on the decision.
class AguiReplay
  THREAD_ID = "docs-agui-relay"
  CLIENT_TOOL = "poetry.sections.set_value"
  USER_TEXT = "Which plan fits a 10-person team? Show me the pricing tab."
  APPROVAL = { "id" => "int-trial", "reason" => "approval",
               "message" => "Start a 30-day Team trial for the workspace?" }.freeze

  class << self
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
      [ { "version" => "v1.0",
          "createSurface" => {
            "surfaceId" => "trial", "catalogId" => Poetry::Agent::A2UI::Catalogs::Basic::ID, "sendDataModel" => true,
            "dataModel" => { "email" => "" },
            "components" => [
              { "id" => "root", "component" => "Column", "children" => %w[title note email remind] },
              { "id" => "title", "component" => "Text", "text" => "### Trial TR-3041 is live" },
              { "id" => "note", "component" => "Text", "variant" => "caption",
                "text" => "Ends in 30 days. Want a reminder three days before?" },
              { "id" => "email", "component" => "TextField", "label" => "Reminder email", "value" => { "path" => "/email" },
                "placeholder" => "you@example.com",
                "checks" => [ { "condition" => { "call" => "email", "args" => { "value" => { "path" => "/email" } } },
                               "message" => "Enter a valid email" } ] },
              { "id" => "remind", "component" => "Button", "child" => "remind_label", "variant" => "primary",
                "action" => { "event" => { "name" => "set_reminder", "context" => { "email" => { "path" => "/email" } } } },
                "checks" => [ { "condition" => { "call" => "required", "args" => { "value" => { "path" => "/email" } } },
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
    # the client tool resolved with the browser's result when given.
    #
    # @param index [Integer]
    # @param decision [Boolean, nil]
    # @param tool_result [String, nil]
    # @param email [String, nil]
    # @return [Poetry::Agent::AGUI::Transcript]
    def transcript_before(index, decision: nil, tool_result: nil, email: nil)
      transcript = Poetry::Agent::AGUI::Transcript.new(client_tools: [ CLIENT_TOOL ])
      (1...index).each do |run|
        transcript.apply_all(events(run, decision: decision, email: email).map { |event| event.except("_sleep") })
        transcript.resolve_client_tool("c-tab", tool_result || '{"value":"pricing","changed":true}') if run == 1
      end
      transcript
    end

    private

    def run_one
      [
        run_started("r1"),
        *reasoning("m1", "The team size points at the Team plan; the plans tool has the current numbers."),
        *text("m1", "For a 10-person team the Team plan fits: per-seat pricing with the admin controls included. "),
        tool_start("c-plans", "lookup_plans", "m1"),
        { "type" => "TOOL_CALL_ARGS", "toolCallId" => "c-plans", "delta" => '{"seats":10}', "_sleep" => 250 },
        { "type" => "TOOL_CALL_END", "toolCallId" => "c-plans" },
        { "type" => "TOOL_CALL_RESULT", "messageId" => "t-plans", "toolCallId" => "c-plans",
          "content" => '{"plans":[{"name":"Team","seat_price":12,"min_seats":5},{"name":"Business","seat_price":24,"min_seats":25}]}',
          "_sleep" => 700 },
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
        *text("m2", "You're on the pricing tab. The Team plan comes with a 30-day trial - want me to start one?"),
        { "type" => "RUN_FINISHED", "threadId" => THREAD_ID, "runId" => "r2",
          "outcome" => { "type" => "interrupt", "interrupts" => [ APPROVAL ] } }
      ]
    end

    def run_three(decision)
      if decision
        [
          run_started("r3"),
          tool_start("c-trial", "start_trial", "m3"),
          { "type" => "TOOL_CALL_ARGS", "toolCallId" => "c-trial", "delta" => '{"plan":"Team","days":30}', "_sleep" => 200 },
          { "type" => "TOOL_CALL_END", "toolCallId" => "c-trial" },
          { "type" => "TOOL_CALL_RESULT", "messageId" => "t-trial", "toolCallId" => "c-trial",
            "content" => '{"trial":"TR-3041","ends":"in 30 days"}', "_sleep" => 700 },
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

    def run_started(run_id)
      { "type" => "RUN_STARTED", "threadId" => THREAD_ID, "runId" => run_id }
    end

    def run_finished(run_id)
      { "type" => "RUN_FINISHED", "threadId" => THREAD_ID, "runId" => run_id }
    end

    def tool_start(id, name, message_id)
      { "type" => "TOOL_CALL_START", "toolCallId" => id, "toolCallName" => name, "parentMessageId" => message_id, "_sleep" => 300 }
    end

    def reasoning(message_id, sentence)
      [ { "type" => "REASONING_MESSAGE_START", "messageId" => message_id } ] +
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
