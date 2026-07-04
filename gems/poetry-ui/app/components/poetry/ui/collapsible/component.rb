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
        CONTROLLER = %i[poetry core state].freeze

        AGENT_RULES = [
          "The trigger is with_trigger { \"label\" } - a real button, wired for you (aria-expanded/controls).",
          "Server-render the initial state via open: - never toggle data-open/data-closed by hand.",
          "Content stays in the DOM when closed (hidden) - do not conditionally render it.",
          "For URL-controlled disclosure without JS, render open: from params - the same markup serves both."
        ].freeze

        option :open, :boolean, default: false

        renders_one :trigger, lambda { |**options, &block|
          attrs = {
            type: "button", "data-slot" => "collapsible-trigger",
            "aria-expanded" => open.to_s, "aria-controls" => content_id
          }.merge(stimulus_attributes do |state|
            state.with_target(:trigger)
            state.with_action(:toggle, on: :click)
          end).merge(options)
          content_tag(:button, attrs, &block)
        }

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
              .merge(stimulus_attributes(&:register_controller))
              .merge(component_data_attributes)
          )
        end

        def content_attributes
          attrs = {
            "id" => content_id, "data-slot" => "collapsible-content", "data-#{state}" => ""
          }.merge(stimulus_attributes { |state_builder| state_builder.with_target(:content) })
          attrs["hidden"] = true unless open
          attrs
        end

        private

        def instance_id
          @instance_id ||= "poetry-collapsible-#{SecureRandom.hex(4)}"
        end

        def stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          yield Poetry::Core::Stimulus::Builder.new(CONTROLLER, attrs)
          attrs.to_attributes
        end
      end
    end
  end
end
