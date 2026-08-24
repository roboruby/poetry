# frozen_string_literal: true

module Poetry
  module Ui
    # ContextMenu family: the right-click/long-press menu.
    module ContextMenu
      # Shared vocabularies, declared once at module level so the root
      # Component and the nested menu-level classes read the same lists.
      DIRS = %i[ltr rtl].freeze
      SIDES = %i[top right bottom left].freeze

      # The shared menus-family kernel wearing this family identity -
      # SLOT_BUILDERS (reopened at the bottom, once the classes exist) keeps
      # the registry recursion on the family classes.
      #
      # @api private
      module ItemSlots
        extend ActiveSupport::Concern
        include Poetry::Ui::Menus::ItemSlots
      end

      # A context menu: the same menu anatomy as DropdownMenu, opened by
      # right-click or long-press on a SURFACE instead of a button. The
      # surface is NOT a widget - no role, no aria-haspopup, not in the
      # tab order (unless focusable_surface: opts in) - and with no JS
      # the browser-native context menu appears untouched. The menu
      # anchors at the pointer position; side: picks which side of the
      # pointer it opens toward (default right), and collisions can
      # still flip it.
      #
      # @example Right-click surface with actions
      #   render Poetry::Ui::ContextMenu::Component.new do |menu|
      #     menu.with_trigger(tag: :div) { "Right-click this card" }
      #     menu.with_item { "Rename" }
      #     menu.with_item(variant: :destructive) { "Delete" }
      #   end
      class Component < Poetry::Core::Component
        include ItemSlots

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "NEVER make a context menu the only path to an action - it is an invisible affordance; every " \
          "item needs a visible equivalent (a '...' DropdownMenu button, a toolbar, a detail page).",
          "Choose ContextMenu only for right-click-on-an-object semantics; a visible button opening a " \
          "menu is DropdownMenu.",
          "Do not add aria-haspopup or a role to the trigger surface; do not make it focusable except " \
          "via focusable_surface: true.",
          "side: picks which side of the pointer the menu opens toward (top/right/bottom/left, default " \
          ":right); align and offsets are not API - collisions still flip the side.",
          "Wrap the whole logical object (row/card) as the trigger surface, not a fragment.",
          "Destructive items use variant: :destructive AND still confirm irreversible actions via a dialog.",
          "shortcut: is a visual hint only - it does NOT bind the key.",
          "Do not nest a ContextMenu trigger surface inside another ContextMenu trigger surface."
        ].freeze

        # The right-click/long-press SURFACE: wraps arbitrary
        # content (a card, a row, a region); polymorphic tag: (default
        # :span, set tag: :div to wrap block content). NOT a button: no
        # role, no aria-haspopup, no tabindex by default. The inline
        # -webkit-touch-callout suppresses the iOS callout so long-press
        # can run (iOS never fires contextmenu; the timer is the only
        # touch path there).
        renders_one :trigger, lambda { |**options, &block|
          tag_name = options.delete(:tag) || :span
          attrs = {
            "id" => trigger_id, "data-slot" => "context-menu-trigger",
            "aria-controls" => content_id,
            "style" => ["-webkit-touch-callout: none", options.delete(:style)].compact.join("; ")
          }.merge(stimulus_attributes_for(:trigger))
          # The surface state: bare data-popup-open while open, NO
          # attribute while closed (absence IS the state).
          attrs["data-popup-open"] = "" if open
          attrs["data-disabled"] = "" if disabled
          if focusable_surface
            attrs["tabindex"] = "0"
            attrs["aria-keyshortcuts"] = "Shift+F10"
          end
          content_tag(tag_name, Poetry::Core::HTML::Attributes.merged(attrs, options)) { capture(&block) }
        }

        use_stimulus do
          on :root do
            controller :context_menu do
              register
              value :long_press_delay
              value :disabled
            end
            controller :menu do
              register
              value :open
              value :modal
              value :loop
            end
            controller :popper do
              register
              # side: is the one placement knob; align start / side_offset
              # 2 stay fixed; collisions still flip the side.
              value :side
              value :align, :start
              value :side_offset, 2
              value :avoid_collisions, true
            end
          end
          # The surface's wiring: contextmenu + the long-press pointer set;
          # popper's anchor target is the FALLBACK rect for positionless
          # opens (the stored virtual anchor point wins).
          on :trigger do
            controller :context_menu do
              action :open, on: :contextmenu
              action :press_start, on: :pointerdown
              action :press_cancel, on: %i[pointermove pointerup pointercancel]
            end
            controller(:popper) { target :anchor }
          end
          on :content do
            controller(:popper) { target :content }
          end
          on :item do
            controller(:menu) { action :activate, on: :click }
          end
          on :sub_trigger do
            controller :menu do
              action :sub_enter, on: :pointerenter
              action :sub_leave, on: :pointerleave
              action :open_sub, on: :click
            end
            controller(:popper) { target :anchor }
          end
        end

        # Server-renders the menu open (rare - context menus normally
        # open from the gesture).
        option :open, :boolean, default: false
        # Traps focus in the open menu; false keeps the page interactive.
        option :modal, :boolean, default: true
        # Wraps arrow-key movement past either end of the menu.
        option :loop, :boolean, default: false
        # Touch long-press duration in ms before the menu opens.
        option :long_press_delay, :integer, default: 700
        # Inerts the surface - no gesture opens the menu.
        option :disabled, :boolean, default: false
        # The menu's accessible name (localized fallback when omitted).
        option :label, :string
        # Puts the surface in the tab order and advertises Shift+F10.
        option :focusable_surface, :boolean, default: false
        # Writing-direction override (ltr/rtl) stamped on the root.
        option :dir, :symbol
        # Which side of the pointer the menu opens toward; collisions may
        # still flip it.
        option :side, :symbol, default: :right

        validates :dir, inclusion: { in: DIRS }, allow_nil: true
        validates :side, inclusion: { in: SIDES }

        part "context-menu", "Root wrapper hosting the context-menu + menu + popper controllers " \
                             "around the surface and content"
        part "context-menu-trigger", "The right-click/long-press SURFACE wrapping the logical object " \
                                     "- not a widget: no role, no aria-haspopup",
             states: {
               "data-popup-open" => "the menu is open (absence is the closed state - no aria-expanded " \
                                    "on a role-less surface)",
               "data-disabled" => "the surface is inert (disabled: true)"
             }
        part "context-menu-content", "The role=menu popup panel - anchored at the pointer via popper's " \
                                     "virtual-anchor mode; open state and animation ride here",
             states: {
               "data-open" => "menu is open (presence flips the pair at runtime)",
               "data-closed" => "menu is closed or animating out (the server-rendered state)",
               "data-side" => { condition: "the placement side (the side: option, default right; popper " \
                                           "re-writes it after collision flips)",
                                values: %w[top right bottom left] },
               "data-align" => { condition: "the alignment (forced start initially; popper re-resolves it)",
                                 values: %w[start center end] }
             },
             vars: {
               "--transform-origin" => "popper's anchor-facing animation origin",
               "--available-width" => "popper: viewport space left for the panel (post-flip)",
               "--available-height" => "popper: viewport space left for the panel (post-flip)",
               "--anchor-width" => "popper: the anchor rect's measured width",
               "--anchor-height" => "popper: the anchor rect's measured height"
             }
        part "context-menu-group", "role=group semantic grouping between separators"
        part "context-menu-label", "Non-interactive heading for a run of items"
        part "context-menu-item", "One role=menuitem action row",
             states: {
               "data-variant" => "default or destructive (the danger treatment)",
               "data-inset" => "indented to align with checkbox/radio item text (inset: true)",
               "data-disabled" => "item is disabled (always written together with aria-disabled)"
             }
        part "context-menu-checkbox-item", "A role=menuitemcheckbox toggle row",
             states: {
               "data-checked" => "checked (the controller re-writes the pair with aria-checked on " \
                                 "activation)",
               "data-unchecked" => "unchecked",
               "data-disabled" => "item is disabled (always written together with aria-disabled)",
               "data-close-on-select" => "per-item override of the menu's close-on-select default " \
                                         "(\"false\" keeps the menu open)"
             }
        part "context-menu-radio-group", "role=group scoping one single-select value",
             states: {
               "data-value" => "the selected radio value (the controller re-writes it on change)"
             }
        part "context-menu-radio-item", "A role=menuitemradio row inside a radio group",
             states: {
               "data-checked" => "the selected radio (the controller re-writes the pair with aria-checked)",
               "data-unchecked" => "not selected",
               "data-value" => "the radio's value"
             }
        part "context-menu-item-indicator", "The check/circle glyph slot inside checkbox and radio " \
                                            "items - state rides the parent item; the glyph stays " \
                                            "decorative"
        part "context-menu-separator", "role=separator rule between groups"
        part "context-menu-shortcut", "The trailing keybinding HINT - aria-hidden, never binds the key"
        part "context-menu-sub", "A submenu scope - hosts its own popper around the sub trigger/" \
                                 "content pair"
        part "context-menu-sub-trigger", "The role=menuitem row opening its submenu",
             states: {
               "data-popup-open" => "its submenu is open (written with aria-expanded; absence is the " \
                                    "closed state)",
               "data-inset" => "indented to align with checkbox/radio item text (inset: true)"
             }
        part "context-menu-sub-content", "The nested role=menu panel - its own popper content on the " \
                                         "same presence machinery",
             states: {
               "data-open" => "submenu is open (presence flips the pair at runtime)",
               "data-closed" => "submenu is closed (the server-rendered state)",
               "data-side" => { condition: "the placement side (right/left by direction; popper resolves " \
                                           "it at runtime)",
                                values: %w[top right bottom left] },
               "data-align" => { condition: "the alignment against the sub-trigger (popper resolves it " \
                                            "at runtime)",
                                 values: %w[start center end] }
             },
             vars: {
               "--transform-origin" => "popper's anchor-facing animation origin",
               "--available-width" => "popper: viewport space left for the panel (post-flip)",
               "--available-height" => "popper: viewport space left for the panel (post-flip)",
               "--anchor-width" => "popper: the sub-trigger's measured width",
               "--anchor-height" => "popper: the sub-trigger's measured height"
             }

        # Enforces the required surface and at least one item.
        # @api private
        def before_render
          raise ArgumentError, "ContextMenu requires with_trigger (the right-click surface)" unless trigger?
          raise ArgumentError, "ContextMenu requires at least one item" unless items?
        end

        # The surface's id.
        # @api private
        def trigger_id
          "#{instance_id}-trigger"
        end

        # The menu panel's id - the surface's aria-controls target.
        # @api private
        def content_id
          "#{instance_id}-content"
        end

        # Attributes for the root wrapper.
        # @api private
        def root_attributes
          root = { "data-slot" => "context-menu" }
          root["dir"] = dir.to_s if dir
          html_attributes.merge_if_not_set(
            root.merge(stimulus_attributes_for(:root)).merge(component_data_attributes)
          )
        end

        # Attributes for the role=menu panel.
        # @api private
        def content_attributes
          attrs = {
            "id" => content_id, "role" => "menu", "aria-orientation" => "vertical",
            # No aria-labelledby to the trigger (it is not a widget - the
            # delta): the menu's name is label: -> the i18n fallback.
            "aria-label" => label.presence || t("poetry.context_menu.menu_label_fallback"),
            "tabindex" => "-1",
            "data-slot" => "context-menu-content", (open ? "data-open" : "data-closed") => "",
            # The initial placement (side: option; re-resolved live by popper).
            "data-side" => side.to_s, "data-align" => "start",
            "class" => css(:content)
          }.merge(stimulus_attributes_for(:content))
          attrs["hidden"] = true unless open
          attrs
        end

        private

        def menu_dir
          dir
        end

        # Server-stable unique id pair (aria-controls is the controller's
        # portal-safe trigger->content seam).
        def instance_id
          @instance_id ||= poetry_instance_id("poetry-context-menu")
        end
      end

      # role=group semantic grouping between separators - the shared kernel
      # anatomy wearing this family identity.
      #
      # @api private
      class Group < Poetry::Ui::Menus::Group
        include ItemSlots
      end
      

      # role=group scoping the single-select value for its radio items -
      # the shared kernel anatomy wearing this family identity.
      #
      # @api private
      class RadioGroup < Poetry::Ui::Menus::RadioGroup
      end
      

      # A submenu scope (recursive item union on its own popper) - the
      # shared kernel anatomy wearing this family identity.
      #
      # @api private
      class Sub < Poetry::Ui::Menus::Sub
        include ItemSlots
      end
      

      # The builder classes behind lambda-wrapped slot types: a
      # lambda hides its return class from introspection, so the owner
      # declares it and the registry walker recurses into the builder's own
      # call surface (with_sub yields a Sub with its own items).
      # REQUIRED_SLOTS states the same facts the before_render
      # raises enforce, so static checks can flag omissions without
      # rendering.
      module ItemSlots
        SLOT_BUILDERS = { sub: Sub, group: Group, radio_group: RadioGroup }.freeze
      end

      class Component
        # The required slots, stated statically for static checks.
        REQUIRED_SLOTS = { trigger: "the right-click surface", item: "at least one item" }.freeze
      end

      class Group
        # The required slots, stated statically for static checks.
        REQUIRED_SLOTS = { item: "at least one item" }.freeze
      end

      class RadioGroup
        # The required slots, stated statically for static checks.
        REQUIRED_SLOTS = { radio_item: "at least one radio item" }.freeze
      end

      class Sub
        # The required slots, stated statically for static checks.
        REQUIRED_SLOTS = { trigger: "the sub-menu item", item: "at least one item" }.freeze
      end
    end
  end
end
