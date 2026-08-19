# frozen_string_literal: true

module Poetry
  module Ui
    module Dialog
      # The Dialog - the depth-moat overlay, on the PLATFORM trap:
      # a native <dialog> + showModal() owns focus trapping, Esc, top-layer
      # stacking, and focus return; the poetry--core--dialog controller adds
      # the data-open/data-closed pair, backdrop dismissal, and the scroll
      # lock. The title is
      # REQUIRED (the accessible name - aria-labelledby is always wired).
      class Component < Poetry::Core::Component
        include Poetry::Ui::ComposableTrigger

        AGENT_RULES = [
          "with_trigger(compose: true) { |wiring| ... } composes YOUR control as the trigger: " \
          "the block is yielded the wiring (id/aria + data: with the overlay's trigger slot " \
          "and Stimulus behavior) - splat it onto a wiring-free control " \
          "(poetry_sidebar_menu_button, a plain tag); without compose: the classic composed " \
          "Button renders.",
          "Open dialogs with with_trigger(...) - never a hand-wired button.",
          "with_title is REQUIRED (the accessible name); with_description when the purpose needs explaining.",
          "Confirmations that must not be lost use dismissible: false (backdrop clicks stop closing).",
          "show_close_button: false removes the corner X - keep a footer action (Esc still closes).",
          "Destructive confirmations pair a destructive Button in the footer - never auto-submit."
        ].freeze

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

        option :dismissible, :boolean, default: true

        # Source parity: showCloseButton - false drops the corner X (the
        # forced-choice recipe: footer actions and Esc remain). Sheet
        # inherits this.
        option :show_close_button, :boolean, default: true
        # Merged onto the <dialog> panel (upstream's DialogContent/
        # SheetContent className seam - e.g. max-h-[50vh] caps a
        # top/bottom sheet).
        option :content_class, :string

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

        # The trigger is a poetry Button wired to open the dialog - agents
        # pass Button props: with_trigger(variant: :outline) { "Open" }.
        renders_one :trigger, lambda { |**options, &block|
          composed_trigger({ "data-action" => stimulus_action(:open) }, options, &block) || begin
            options[:data] = { action: stimulus_action(:open) }.merge(options[:data] || {}) do |key, wired, caller|
              key == :action ? Poetry::Core::Config.current.stimulus_merger.merge_actions(wired, caller) : caller
            end
            Button::Component.new(**options, &block)
          end
        }
        renders_one :title
        renders_one :description
        renders_one :footer

        # The same facts the before_render raise enforces, stated statically
        #: poetry check flags the omission without rendering (the
        # menu crash class - required slots the contract kept silent).
        REQUIRED_SLOTS = { title: "the accessible name" }.freeze

        # The forwarding-lambda component fact: with_trigger renders a
        # Button - callers get Button's full typed-slot contract statically.
        SLOT_RENDERS = { trigger: Button::Component }.freeze

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
            { "data-slot" => "dialog" }
              .merge(stimulus_attributes_for(:root))
              .merge(component_data_attributes)
          )
        end

        def dialog_attributes
          attrs = {
            "class" => css(:content, class: content_class),
            "data-slot" => "dialog-content",
            "data-closed" => "",
            "aria-labelledby" => title_id
          }.merge(stimulus_attributes_for(:content))
          attrs["aria-describedby"] = description_id if description?
          attrs
        end

        # Validated action descriptor for the template's close button -
        # resolves against the class's OWN declarations (Sheet/Drawer get
        # their controller without overriding).
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
        def html_attributes
          return super unless Poetry::Core::Config.current.css_mode == :tailwind

          @html_attributes.merge(class: classnames(@html_attributes[:class]))
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
