# frozen_string_literal: true

module Poetry
  module Ui
    # Trace family: the steps an agent takes, one line each.
    module Trace
      # The shape every agent step takes (shadcn@4.23.0's Trace): a column
      # of lines - an icon, a title, a muted description - where a step with
      # detail becomes a disclosure that reveals it (tool output, a
      # reasoning summary, a plan's sub-steps). A step's status: tints it:
      # :running shimmers the title (off under reduced motion), :error turns
      # it destructive, :pending dims it. The title carries the words
      # ("Running", "Ran", "Failed to run") - status: is the look, not the
      # announcement.
      #
      # @example
      #   render Poetry::Ui::Trace::Component.new do |trace|
      #     trace.with_step("Searched the docs", icon: :search, description: "3 results")
      #     trace.with_step("Running the tests", icon: :"flask-conical", status: :running)
      #   end
      #
      # @example A step with detail
      #   render Poetry::Ui::Trace::Component.new do |trace|
      #     trace.with_step("Ran git status", icon: :terminal, description: "0.4s") do
      #       render Poetry::Ui::CodeBlock::Component.new(code: output, size: :sm, wrap: true)
      #     end
      #   end
      class Component < Poetry::Core::Component
        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "The steps an agent takes (reasoning, tool calls, searches, a plan) are a Trace - never a " \
          "hand-rolled column of muted rows.",
          "with_step(title, icon:, description:, status:) is one line; a block makes it a disclosure " \
          "that reveals the detail (tool output in a poetry_code_block size: :sm, a reasoning summary).",
          "Map a tool call's state to status: and to the title's words: running -> status: :running, " \
          "\"Running ...\"; failed -> status: :error, \"Failed to run ...\"; waiting -> status: :pending; " \
          "done -> no status, \"Ran ...\". The title is what assistive tech reads.",
          "href: makes a step a link (a source, a file the agent changed)."
        ].freeze

        # The required slots, stated statically so static checks can flag
        # a missing step without rendering.
        REQUIRED_SLOTS = { step: "at least one step (with_step(title, ...))" }.freeze

        # The closed vocabulary for a step's status.
        STATUSES = %i[running error pending].freeze

        use_stimulus do
          on :collapsible do
            controller(:state) { register }
          end
          on :collapsible_trigger do
            controller :state do
              target :trigger
              action :toggle, on: :click
            end
          end
          on :collapsible_content do
            controller(:state) { target :content }
          end
        end

        renders_many :steps,
                     doc: "One step: the title (positional), optional icon:, description:, status: (:running, " \
                          ":error, :pending), href: (a link), and open: for a step with detail - the detail is " \
                          "the block, which makes the step a disclosure.",
                     renders: lambda { |title, icon: nil, description: nil, status: nil, href: nil, open: false,
                                        &block|
                       step_markup(title, icon:, description:, status:, href:, open:, detail: block)
                     }

        part "trace", "The column of steps"
        part "trace-line", "One step's row - its icon, title and description",
             states: {
               "data-status" => { condition: "status: - the step's state (absent when done)",
                                  values: STATUSES.map(&:to_s) }
             }
        part "trace-icon", "The step's glyph, and the disclosure's chevron (aria-hidden)"
        part "trace-title", "The step's words - shimmers while running"
        part "trace-description", "The muted trailing note - a duration, a count"
        part "trace-collapsible", "A step with detail - the state controller's root",
             states: {
               "data-open" => "the detail is shown (server-rendered from open:; the controller flips the pair)",
               "data-closed" => "the detail is hidden"
             }
        part "trace-collapsible-trigger", "The disclosure button around the step's line - mirrors aria-expanded"
        part "trace-collapsible-content", "The detail panel - its height animates over the measured " \
                                          "--collapsible-panel-height",
             states: {
               "data-open" => "the detail is open or entering",
               "data-closed" => "the detail is closed or animating out (hidden lands after the exit)",
               "data-starting-style" => "the first painted frame of an entry (controller-written)",
               "data-ending-style" => "the whole exit, until hidden lands (controller-written)"
             }
        part "trace-collapsible-content-inner", "The detail itself - indented on the theme's rail"

        # Raises without a step.
        # @api private
        def before_render
          raise ArgumentError, "Trace requires at least one with_step" unless steps?
        end

        # Renders the column of steps.
        # @api private
        def call
          content_tag(:div, safe_join(steps.map(&:to_s)), **root_attributes)
        end

        private

        # One step's markup: a line, a line in a link, or a disclosure over its detail.
        def step_markup(title, icon:, description:, status:, href:, open:, detail:)
          if status && !STATUSES.include?(status.to_sym)
            raise ArgumentError,
                  "trace step status: #{status.inspect} is not one of #{STATUSES.map(&:inspect).join(", ")}"
          end

          line = line_markup(title, icon:, description:, status:)
          return collapsible_markup(line, open:, detail:) if detail

          href ? content_tag(:a, line, href:) : line
        end

        # The step's row: the icon, the title and the description.
        def line_markup(title, icon:, description:, status:)
          parts = []
          parts << icon_markup(icon) if icon
          parts << content_tag(:span, title, **element_attributes(:title))
          parts << content_tag(:span, description, **element_attributes(:description)) if description
          content_tag(:span, safe_join(parts), **element_attributes(:line, { "data-status" => status&.to_s }.compact))
        end

        # A trace icon around a poetry Icon (aria-hidden), with extra classes for the chevron.
        def icon_markup(name, extra = nil)
          attrs = { "aria-hidden" => "true" }
          attrs["class"] = [css(:icon), extra].compact.join(" ") if extra
          content_tag(:span, render(Icon::Component.new(name:)), **element_attributes(:icon, attrs))
        end

        # A step with detail on the Collapsible contract: the trigger around the line, then the panel.
        def collapsible_markup(line, open:, detail:)
          state = open ? "open" : "closed"
          content_id = "#{poetry_instance_id("poetry-trace")}-step-#{step_counter}-content"
          trigger = content_tag(:button, safe_join([line, icon_markup(:"chevron-right", css(:chevron))]),
                                **element_attributes(:collapsible_trigger, {
                                                       "type" => "button", "aria-expanded" => open.to_s,
                                                       "aria-controls" => content_id
                                                     }))
          inner = content_tag(:div, capture(&detail), **element_attributes(:collapsible_content_inner))
          content_attrs = { "id" => content_id, "data-#{state}" => "" }
          content_attrs["hidden"] = true unless open
          panel = content_tag(:div, inner, **element_attributes(:collapsible_content, content_attrs))
          content_tag(:div, trigger + panel, **element_attributes(:collapsible, { "data-#{state}" => "" }))
        end

        # Numbers the disclosures within this trace, for their panel ids.
        def step_counter
          @step_counter = (@step_counter || 0) + 1
        end
      end
    end
  end
end
