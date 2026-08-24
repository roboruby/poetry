# frozen_string_literal: true

module Poetry
  module Ui
    # Collapsible family: the plain show/hide disclosure.
    module Collapsible
      # A disclosure: a trigger button that shows and hides one content
      # panel. The server renders the initial open/closed state, the
      # trigger mirrors aria-expanded, and closed content stays in the
      # DOM (hidden) so it survives re-renders and stays findable -
      # exit animations are awaited before hiding.
      #
      # @example
      #   render Poetry::Ui::Collapsible::Component.new do |collapsible|
      #     collapsible.with_trigger { "Show details" }
      #     tag.div("Hidden until disclosed.")
      #   end
      class Component < Poetry::Core::Component
        include Poetry::Ui::ComposableTrigger

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          ComposableTrigger::AGENT_RULE,
          "The trigger is with_trigger { \"label\" } - a real button, wired for you (aria-expanded/controls).",
          "Server-render the initial state via open: - never toggle data-open/data-closed by hand.",
          "Content stays in the DOM when closed (hidden) - do not conditionally render it.",
          "For URL-controlled disclosure without JS, render open: from params - the same markup serves both."
        ].freeze

        # The required slots, stated statically so static checks can flag
        # a missing trigger without rendering.
        REQUIRED_SLOTS = { trigger: "the disclosure control" }.freeze

        # The disclosure control - a real button, wired for you
        # (aria-expanded, aria-controls); options merge onto it.
        renders_one :trigger, lambda { |**options, &block|
          attrs = {
            type: "button", "data-slot" => "collapsible-trigger",
            "aria-expanded" => open.to_s, "aria-controls" => content_id
          }.merge(stimulus_attributes_for(:trigger))
          composed_trigger(attrs, options, &block) ||
            content_tag(:button, Poetry::Core::HTML::Attributes.merged(attrs, options), &block)
        }

        use_stimulus do
          on :root do
            controller(:state) { register }
          end
          on :trigger do
            controller :state do
              target :trigger
              action :toggle, on: :click
            end
          end
          on :content do
            controller(:state) { target :content }
          end
        end

        # The server-rendered initial state; the trigger toggles it
        # client-side.
        option :open, :boolean, default: false

        part "collapsible", "The disclosure root - the state controller flips the pair here",
             states: {
               "data-open" => "expanded (server-rendered from open:; the controller flips the pair at runtime)",
               "data-closed" => "collapsed (the server-rendered default)"
             }
        part "collapsible-trigger", "The disclosure button - mirrors aria-expanded",
             states: {
               "data-panel-open" => "its content is open (Base UI trigger parity, controller-written; " \
                                    "absent while closed)"
             }
        part "collapsible-content", "The disclosure panel - stays in the DOM when closed (hidden) " \
                                    "and rides the presence helper on exit",
             states: {
               "data-open" => "content is open or entering",
               "data-closed" => "content is closed or animating out (hidden lands after the exit finishes)"
             }

        # A missing body yields a trigger disclosing an empty panel.
        requires_content "the disclosed panel body"

        # Enforces the required trigger and panel body.
        # @api private
        def before_render
          raise ArgumentError, "Collapsible requires with_trigger (the disclosure control)" unless trigger?
          ensure_content!
        end

        # The state word behind the data-* stamps.
        # @api private
        def state
          open ? "open" : "closed"
        end

        # The panel's id - the trigger's aria-controls target.
        # @api private
        def content_id
          @content_id ||= "#{instance_id}-content"
        end

        # Attributes for the disclosure root.
        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "collapsible", "data-#{state}" => "" }
              .merge(stimulus_attributes_for(:root))
              .merge(component_data_attributes)
          )
        end

        # Attributes for the content panel.
        # @api private
        def content_attributes
          attrs = {
            "id" => content_id, "data-slot" => "collapsible-content", "data-#{state}" => ""
          }.merge(stimulus_attributes_for(:content))
          attrs["hidden"] = true unless open
          attrs
        end

        private

        def instance_id
          @instance_id ||= poetry_instance_id("poetry-collapsible")
        end
      end
    end
  end
end
