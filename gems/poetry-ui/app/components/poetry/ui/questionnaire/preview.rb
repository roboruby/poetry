# frozen_string_literal: true

module Poetry
  module Ui
    module Questionnaire
      # The Questionnaire preview matrix: the hero three-question flow
      # (required single choice + free text, optional multiple, required
      # closer), plus the per-axis scenarios the contracts hold to DOM -
      # shortcuts, an answered/checked state, a skipped optional item, a
      # disabled choice, and a custom progress readout.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(url: "#", shortcuts: :letters, class: "w-full max-w-md") do |q|
            q.with_progress
            q.with_item(name: "direction", title: "What should the agent build next?",
                        description: "Choose a direction or describe another task.",
                        required: true) do |item|
              item.with_choice(value: "tool-calls", label: "Tool call timeline",
                               description: "Show what the agent ran and what came back.")
              item.with_choice(value: "approvals", label: "Approval checkpoints",
                               description: "Ask before sensitive or destructive actions.")
              item.with_input(label: "Another agent feature", placeholder: "Describe another feature…")
            end
            q.with_item(name: "signals", title: "What should every update include?",
                        description: "Select all that apply, or skip this question.",
                        multiple: true) do |item|
              item.with_choice(value: "progress", label: "Progress")
              item.with_choice(value: "decisions", label: "Decisions")
              item.with_choice(value: "risks", label: "Risks")
            end
            q.with_item(name: "timing", title: "When should work begin?", required: true) do |item|
              item.with_choice(value: "now", label: "Start now")
              item.with_choice(value: "backlog", label: "Add it to the backlog")
            end
          end
        end

        # Server-rendered answered state: checked choice, answered status,
        # the second item active via default_item.
        def answered_and_resumed
          render_component(url: "#", default_item: "detail", class: "w-full max-w-md") do |q|
            q.with_progress
            q.with_item(name: "prototype", title: "What should we prototype?", required: true) do |item|
              item.with_choice(value: "delegation", label: "Delegation", checked: true)
              item.with_choice(value: "prompts", label: "Question prompts")
            end
            q.with_item(name: "detail", title: "How much detail?") do |item|
              item.with_choice(value: "focused", label: "Focused")
              item.with_choice(value: "complete", label: "Complete flow")
            end
          end
        end

        # Number shortcuts + a disabled choice + a pre-filled free answer.
        def numbers_and_disabled
          render_component(url: "#", shortcuts: :numbers, class: "w-full max-w-md") do |q|
            q.with_item(name: "cadence", title: "How often should we check in?",
                        description: "Weekly keeps the loop tight.") do |item|
              item.with_choice(value: "daily", label: "Daily", disabled: true)
              item.with_choice(value: "weekly", label: "Weekly")
              item.with_input(label: "Another cadence", placeholder: "Every…", value: "Fortnightly")
            end
          end
        end

        # A custom progress readout (data-custom - the controller leaves it).
        def custom_progress
          render_component(url: "#", class: "w-full max-w-md") do |q|
            q.with_progress { "Step 1 · Kickoff" }
            q.with_item(name: "kickoff", title: "Ready to start?", required: true) do |item|
              item.with_choice(value: "yes", label: "Yes")
              item.with_choice(value: "later", label: "Later")
            end
          end
        end
      end
    end
  end
end
