# frozen_string_literal: true

module Poetry
  module Ui
    module Dialog
      # The Dialog - the depth-moat overlay, on the PLATFORM trap:
      # a native <dialog> + showModal() owns focus trapping, Esc, top-layer
      # stacking, and focus return; the poetry--core--dialog controller adds
      # data-state, backdrop dismissal, and the scroll lock. The title is
      # REQUIRED (the accessible name - aria-labelledby is always wired).
      class Component < Poetry::Core::Component
        AGENT_RULES = [
          "Open dialogs with with_trigger(...) - never a hand-wired button.",
          "with_title is REQUIRED (the accessible name); with_description when the purpose needs explaining.",
          "Confirmations that must not be lost use dismissible: false (backdrop clicks stop closing).",
          "Destructive confirmations pair a destructive Button in the footer - never auto-submit."
        ].freeze

        option :dismissible, :boolean, default: true

        # The trigger is a poetry Button wired to open the dialog - agents
        # pass Button props: with_trigger(variant: :outline) { "Open" }.
        renders_one :trigger, lambda { |**options, &block|
          options[:data] = { action: "poetry--core--dialog#open" }.merge(options[:data] || {})
          Button::Component.new(**options, &block)
        }
        renders_one :title
        renders_one :description
        renders_one :footer

        def before_render
          raise ArgumentError, "Dialog requires with_title (the accessible name)" unless title?
        end

        def title_id
          "#{instance_id}-title"
        end

        def description_id
          "#{instance_id}-description"
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            {
              "data-slot" => "dialog",
              "data-controller" => "poetry--core--dialog",
              "data-poetry--core--dialog-dismissible-value" => dismissible
            }.merge(component_data_attributes)
          )
        end

        def dialog_attributes
          attrs = {
            "class" => css(:content),
            "data-slot" => "dialog-content",
            "data-state" => "closed",
            "data-poetry--core--dialog-target" => "dialog",
            "data-action" => "cancel->poetry--core--dialog#close click->poetry--core--dialog#backdropClose",
            "aria-labelledby" => title_id
          }
          attrs["aria-describedby"] = description_id if description?
          attrs
        end

        private

        # Server-stable unique id for the aria wiring (two dialogs on one
        # page must not share label ids).
        def instance_id
          @instance_id ||= "poetry-dialog-#{SecureRandom.hex(4)}"
        end
      end
    end
  end
end
