# frozen_string_literal: true

module Poetry
  module Ui
    # Dialog family: the modal overlay on the native <dialog> element.
    module Dialog
      # A modal dialog built ON the platform: a native <dialog> +
      # showModal() owns focus trapping, Esc, top-layer stacking, and
      # focus return; poetry adds the data-open/data-closed pair,
      # backdrop dismissal, and the scroll lock. The title is REQUIRED
      # (the accessible name - aria-labelledby is always wired).
      #
      # @example A confirmation dialog
      #   render Poetry::Ui::Dialog::Component.new do |dialog|
      #     dialog.with_trigger(variant: :outline) { "Open" }
      #     dialog.with_title { "Are you sure?" }
      #     dialog.with_description { "This cannot be undone." }
      #   end
      class Component < Poetry::Core::Component
        include Poetry::Ui::ComposableTrigger
        include Poetry::Ui::FamilyIdentity

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          ComposableTrigger::AGENT_RULE,
          "Open dialogs with with_trigger(...) - never a hand-wired button.",
          "with_title is REQUIRED (the accessible name); with_description when the purpose needs explaining.",
          "Confirmations that must not be lost use dismissible: false (backdrop clicks stop closing).",
          "show_close_button: false removes the corner X - keep a footer action (Esc still closes).",
          "Destructive confirmations pair a destructive Button in the footer - never auto-submit."
        ].freeze

        # The required slots, stated statically so static checks can flag
        # a missing title without rendering.
        REQUIRED_SLOTS = { title: "the accessible name" }.freeze

        # The forwarding-lambda fact: with_trigger renders a Button -
        # callers get Button's full typed-slot contract statically.
        SLOT_RENDERS = { trigger: Button::Component }.freeze

        slot_doc :trigger, "The trigger is a poetry Button wired to open the dialog - agents pass Button props: " \
                           "with_trigger(variant: :outline) { \"Open\" }."
        renders_one :trigger, lambda { |**options, &block|
          composed_trigger({ "data-action" => stimulus_action(:open) }, options, &block) || begin
            options[:data] = { action: stimulus_action(:open) }.merge(options[:data] || {}) do |key, wired, caller|
              key == :action ? Poetry::Core::Config.current.stimulus_merger.merge_actions(wired, caller) : caller
            end
            Button::Component.new(**options, &block)
          end
        }
        slot_doc :title, "The heading - the dialog's accessible name; required."
        renders_one :title
        slot_doc :description, "Muted copy under the title, wired to aria-describedby."
        renders_one :description
        slot_doc :footer, "The action row at the bottom of the panel."
        renders_one :footer

        # Sheet and Drawer subclass this and REDECLARE both elements with
        # their own controllers (replace-on-redeclare); the trigger lambda
        # and close_action late-bind through stimulus_action, so subclasses
        # never re-type the entry points.
        use_stimulus do
          on :root do
            controller :dialog do
              register
              value :dismissible
            end
          end
          on :content do
            controller :dialog do
              target :dialog
              action :close, on: :cancel
              action :backdrop_close, on: :click
            end
          end
          # Forwarded descriptors (bare = element-default click): the
          # trigger Button and the corner close button.
          on :trigger do
            controller(:dialog) { action :open }
          end
          on :close do
            controller(:dialog) { action :close }
          end
        end

        option :dismissible, :boolean, default: true,
                                       doc: "Backdrop clicks close the dialog; false keeps confirmations from being " \
                                            "dismissed accidentally (Esc still closes)."

        option :show_close_button, :boolean, default: true,
                                             doc: "Renders the corner X; false forces a deliberate footer choice " \
                                                  "(footer actions and Esc remain). Sheet inherits this."
        option :content_class, :string,
               doc: "Extra classes merged onto the <dialog> panel (e.g. \"max-h-[50vh]\" caps a top/bottom sheet)."

        part "dialog", "Root wrapper around the trigger and the <dialog> element"
        part "dialog-content", "The <dialog> panel - positioning, animation, and the open " \
                               "state ride here",
             states: {
               "data-open" => "panel is open (the controller flips the pair at runtime)",
               "data-closed" => "panel is closed or animating out (the server-rendered state)"
             }
        part "dialog-header", "Title block at the top of the panel"
        part "dialog-title", "The heading - the dialog's accessible name (required slot)"
        part "dialog-description", "Muted copy under the title, wired to aria-describedby"
        part "dialog-footer", "Action row at the bottom of the panel"

        # Enforces the required title.
        # @api private
        def before_render
          raise ArgumentError, "#{family_name} requires with_title (the accessible name)" unless title?
        end

        # The title's id - the aria-labelledby target.
        # @api private
        def title_id
          "#{instance_id}-title"
        end

        # The description's id - the aria-describedby target.
        # @api private
        def description_id
          "#{instance_id}-description"
        end

        # Attributes for the <dialog> panel.
        # @api private
        def dialog_attributes
          attrs = {
            "class" => css(:content, class: panel_classes),
            "data-slot" => "#{family_slot_prefix}-content",
            **panel_stamps,
            "data-closed" => "",
            "aria-labelledby" => title_id
          }.merge(stimulus_attributes_for(:content))
          attrs["aria-describedby"] = description_id if description?
          attrs
        end

        # Validated action descriptor for the template's close button -
        # resolves against the class's OWN declarations (Sheet/Drawer get
        # their controller without overriding).
        # @api private
        def close_action
          stimulus_action(:close)
        end

        # The dialog-family root wrapper is NON-VISUAL - the <dialog> is
        # the visual root. The style resolver renders variant branches only
        # at the dictionary root, so subclasses with a root-level style
        # axis (Sheet's side:, Drawer's direction:) merge the branch into
        # :content themselves - and the inherited html_attributes would
        # paint the same branch on the in-flow wrapper too (the closed
        # Drawer drew its themed border + w-full across the docs mounts).
        # Only the tailwind resolution is stripped: in :bem mode the root
        # block--modifier tokens ARE the host's styling contract.
        # @api private
        def html_attributes
          return super unless Poetry::Core::Config.current.css_mode == :tailwind

          @html_attributes.merge(class: classnames(@html_attributes[:class]))
        end

        private

        # Subclass seams for the panel: extra class values and the family
        # stamps between data-slot and data-closed (Sheet stamps its side,
        # Drawer its swipe direction).
        def panel_classes
          content_class
        end

        def panel_stamps
          {}
        end

        private :title_id, :description_id, :dialog_attributes, :close_action, :html_attributes
      end
    end
  end
end
