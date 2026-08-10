# frozen_string_literal: true

module Poetry
  module Ui
    module Collapsible
      # The first presence consumer (Collapsible): a
      # disclosure on the EXISTING poetry--core--state controller - no new
      # machinery. The server renders open/closed as the data-open/
      # data-closed pair; the
      # trigger mirrors aria-expanded; content stays in the DOM (hidden,
      # searchable by re-render) and rides the presence helper on exit.
      class Component < Poetry::Core::Component
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

        AGENT_RULES = [
          "The trigger is with_trigger { \"label\" } - a real button, wired for you (aria-expanded/controls).",
          "Server-render the initial state via open: - never toggle data-open/data-closed by hand.",
          "Content stays in the DOM when closed (hidden) - do not conditionally render it.",
          "For URL-controlled disclosure without JS, render open: from params - the same markup serves both."
        ].freeze

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

        renders_one :trigger, lambda { |**options, &block|
          attrs = {
            type: "button", "data-slot" => "collapsible-trigger",
            "aria-expanded" => open.to_s, "aria-controls" => content_id
          }.merge(stimulus_attributes_for(:trigger)).merge(options)
          content_tag(:button, attrs, &block)
        }

        # The same facts the before_render raise enforces, stated statically
        #: poetry check flags the omission without rendering (the
        # menu crash class - required slots the contract kept silent).
        REQUIRED_SLOTS = { trigger: "the disclosure control" }.freeze

        def before_render
          raise ArgumentError, "Collapsible requires with_trigger (the disclosure control)" unless trigger?
        end

        def state
          open ? "open" : "closed"
        end

        def content_id
          @content_id ||= "#{instance_id}-content"
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "collapsible", "data-#{state}" => "" }
              .merge(stimulus_attributes_for(:root))
              .merge(component_data_attributes)
          )
        end

        def content_attributes
          attrs = {
            "id" => content_id, "data-slot" => "collapsible-content", "data-#{state}" => ""
          }.merge(stimulus_attributes_for(:content))
          attrs["hidden"] = true unless open
          attrs
        end

        private

        def instance_id
          @instance_id ||= "poetry-collapsible-#{SecureRandom.hex(4)}"
        end
      end
    end
  end
end
