# frozen_string_literal: true

module Poetry
  module Ui
    module DropdownMenu
      # The controller identifiers, declared ONCE - every data attribute
      # derives from them through the Stimulus Builder, validated against
      # the controllers manifest (no hand-written wiring strings).
      SIDES = %i[top right bottom left].freeze
      ALIGNS = %i[start center end].freeze
      DIRS = %i[ltr rtl].freeze

      # The shared menus-family kernel wearing this family identity -
      # SLOT_BUILDERS (reopened at the bottom, once the classes exist) keeps
      # the registry recursion on the family classes.
      module ItemSlots
        extend ActiveSupport::Concern
        include Poetry::Ui::Menus::ItemSlots
      end

      # The menus-family ANCHOR: a button-triggered role=menu popup on
      # the shipped primitive stack.
      # Two hosts, one owned controller: the root carries poetry--core--menu
      # (open/activate/typeahead/submenus) + poetry--core--popper (trigger-
      # anchored positioning); the content's layer controllers (focus-scope,
      # dismissable, roving-focus) are TOKEN-ACTIVATED by the menu
      # controller on open - a statically-connected trap on a hidden menu
      # would steal focus at page load, so the markup renders NO layer
      # tokens (menu_controller.js appends/removes them).
      #
      # @example A menu button with actions
      #   render Poetry::Ui::DropdownMenu::Component.new do |menu|
      #     menu.with_trigger(variant: :outline) { "Open" }
      #     menu.with_item { "Rename" }
      #     menu.with_item(variant: :destructive) { "Delete" }
      #   end
      class Component < Poetry::Core::Component
        include Poetry::Ui::ComposableTrigger

        include ItemSlots

        AGENT_RULES = [
          ComposableTrigger::AGENT_RULE,
          "Use poetry_dropdown_menu - never hand-roll role=menu popups with Tailwind.",
          "Items are ACTIONS. Choosing a form VALUE is a Select/Combobox - do not fake it with radio items.",
          "Navigation items pass with_item(href:) (external: for a new tab); a form action (sign-out, a " \
          "DELETE) passes with_item(submit:, method:). The item renders AS the anchor / submit button " \
          "(role=menuitem on the <a> or <button>) - one interactive element - so NEVER nest a link_to or " \
          "button_to inside an item.",
          "Icon-only triggers MUST have an accessible name (the composed Button's label: rule).",
          "Never write the state attributes (data-popup-open / data-checked / data-unchecked) without " \
          "their aria twin (aria-expanded / aria-checked) - the controller writes both; agents patching " \
          "DOM must too.",
          "Destructive items use variant: :destructive AND still confirm irreversible actions via a dialog.",
          "shortcut: is a visual hint only - it does NOT bind the key; wire a real hotkey separately or omit it.",
          "Do not nest interactive elements inside items (a menuitem IS the interactive unit).",
          "Keep submenus <= 2 levels; prefer grouping + separators over deep nesting.",
          "Critical actions must exist somewhere reachable without JS (menus are JS-required interaction)."
        ].freeze

        # The forwarding-lambda fact: with_trigger renders a Button -
        # callers get Button's full typed-slot contract statically.
        SLOT_RENDERS = { trigger: Button::Component }.freeze

        # The trigger is a poetry Button wired as the menu button (demo
        # parity: with_trigger(variant: :outline) { "Open" }) - the slot
        # owns the aria-haspopup/expanded/controls wiring regardless of
        # the composed content, so composition cannot drop the aria.
        renders_one :trigger, lambda { |**options, &block|
          wiring = {
            "id" => trigger_id, "data-slot" => "dropdown-menu-trigger",
            "aria-haspopup" => "menu", "aria-expanded" => open.to_s, "aria-controls" => content_id
          }.merge(stimulus_attributes_for(:trigger))
          # Base UI trigger state: bare data-popup-open while open, NO
          # attribute while closed (absence IS the state).
          wiring["data-popup-open"] = "" if open
          composed_trigger(wiring, options, &block) || begin
            options[:disabled] = true if disabled && !options.key?(:disabled)
            Button::Component.new(**wiring, **options, &block)
          end
        }

        use_stimulus do
          on :root do
            controller :menu do
              register
              value :open
              value :modal
              value :loop
            end
            controller :popper do
              register
              value :side
              value :align
              value :side_offset
              value :align_offset
              value :avoid_collisions
            end
          end
          on :trigger do
            controller :menu do
              action :toggle, on: :click
              action :trigger_keydown, on: :keydown
            end
            controller(:popper) { target :anchor }
          end
          on :content do
            controller(:popper) { target :content }
          end
          # Anatomy-rendered wiring, declared here so the contract covers
          # the whole family surface (items + submenus render via the
          # escape hatch in the anatomy classes).
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

        option :open, :boolean, default: false
        option :modal, :boolean, default: true
        option :side, :symbol, default: :bottom
        option :align, :symbol, default: :center
        option :side_offset, :integer, default: 4
        option :align_offset, :integer, default: 0
        option :avoid_collisions, :boolean, default: true
        option :loop, :boolean, default: false
        option :dir, :symbol
        option :disabled, :boolean, default: false

        validates :side, inclusion: { in: SIDES }
        validates :align, inclusion: { in: ALIGNS }
        validates :dir, inclusion: { in: DIRS }, allow_nil: true

        # (dropdown-menu-trigger rides the composed Button, so that element
        # belongs to Button's anatomy, not this contract.)
        part "dropdown-menu", "Root wrapper hosting the menu + popper controllers around the trigger " \
                              "and content"
        part "dropdown-menu-content", "The role=menu popup panel - positioning, animation, and the " \
                                      "open state ride here",
             states: {
               "data-open" => "menu is open (presence flips the pair at runtime)",
               "data-closed" => "menu is closed or animating out (the server-rendered state)",
               "data-side" => { condition: "the placement side (popper re-writes it after collision flips)",
                                values: %w[top right bottom left] },
               "data-align" => { condition: "the alignment against the trigger (popper re-resolves it)",
                                 values: %w[start center end] }
             },
             vars: {
               "--transform-origin" => "popper's anchor-facing animation origin",
               "--available-width" => "popper: viewport space left for the panel (post-flip)",
               "--available-height" => "popper: viewport space left for the panel (post-flip)",
               "--anchor-width" => "popper: the trigger's measured width",
               "--anchor-height" => "popper: the trigger's measured height"
             }
        part "dropdown-menu-group", "role=group semantic grouping between separators"
        part "dropdown-menu-label", "Non-interactive heading for a run of items",
             states: {
               "data-inset" => "indented to align with checkbox/radio item text (inset: true)"
             }
        part "dropdown-menu-item", "One role=menuitem action row",
             states: {
               "data-variant" => "default or destructive (the danger treatment)",
               "data-inset" => "indented to align with checkbox/radio item text (inset: true)",
               "data-disabled" => "item is disabled (always written together with aria-disabled)"
             }
        part "dropdown-menu-checkbox-item", "A role=menuitemcheckbox toggle row",
             states: {
               "data-checked" => "checked (the controller re-writes the pair with aria-checked on " \
                                 "activation)",
               "data-unchecked" => "unchecked",
               "data-disabled" => "item is disabled (always written together with aria-disabled)",
               "data-close-on-select" => "per-item override of the menu's close-on-select default " \
                                         "(\"false\" keeps the menu open)"
             }
        part "dropdown-menu-radio-group", "role=group scoping one single-select value",
             states: {
               "data-value" => "the selected radio value (the controller re-writes it on change)"
             }
        part "dropdown-menu-radio-item", "A role=menuitemradio row inside a radio group",
             states: {
               "data-checked" => "the selected radio (the controller re-writes the pair with aria-checked)",
               "data-unchecked" => "not selected",
               "data-value" => "the radio's value"
             }
        part "dropdown-menu-item-indicator", "The check/circle glyph slot inside checkbox and radio " \
                                             "items - state rides the parent item; the glyph stays " \
                                             "decorative"
        part "dropdown-menu-separator", "role=separator rule between groups"
        part "dropdown-menu-shortcut", "The trailing keybinding HINT - aria-hidden, never binds the key"
        part "dropdown-menu-sub", "A submenu scope - hosts its own popper around the sub trigger/" \
                                  "content pair"
        part "dropdown-menu-sub-trigger", "The role=menuitem row opening its submenu",
             states: {
               "data-popup-open" => "its submenu is open (written with aria-expanded; absence is the " \
                                    "closed state)",
               "data-inset" => "indented to align with checkbox/radio item text (inset: true)"
             }
        part "dropdown-menu-sub-content", "The nested role=menu panel - its own popper content on the " \
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

        def before_render
          raise ArgumentError, "DropdownMenu requires with_trigger (the menu button)" unless trigger?
          raise ArgumentError, "DropdownMenu requires at least one item" unless items?
        end

        def trigger_id
          "#{instance_id}-trigger"
        end

        def content_id
          "#{instance_id}-content"
        end

        def root_attributes
          root = { "data-slot" => "dropdown-menu" }
          root["dir"] = dir.to_s if dir
          html_attributes.merge_if_not_set(
            root.merge(stimulus_attributes_for(:root)).merge(component_data_attributes)
          )
        end

        def content_attributes
          attrs = {
            "id" => content_id, "role" => "menu", "aria-orientation" => "vertical",
            "aria-labelledby" => trigger_id, "tabindex" => "-1",
            "data-slot" => "dropdown-menu-content", (open ? "data-open" : "data-closed") => "",
            # Initial placement, re-resolved live by popper on open.
            "data-side" => side, "data-align" => align,
            "class" => css(:content)
          }.merge(stimulus_attributes_for(:content))
          attrs["hidden"] = true unless open
          attrs
        end

        private

        def menu_dir
          dir
        end

        # Server-stable unique id pair for the aria wiring (two menus on
        # one page must not share ids); portal-safe (the controller
        # resolves content via aria-controls, not a Stimulus target).
        def instance_id
          @instance_id ||= poetry_instance_id("poetry-dropdown-menu")
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
      # raises enforce, so poetry check flags the omission without
      # rendering (the menu crash class).
      module ItemSlots
        SLOT_BUILDERS = { sub: Sub, group: Group, radio_group: RadioGroup }.freeze
      end

      class Component
        REQUIRED_SLOTS = { trigger: "the menu button", item: "at least one item" }.freeze
      end

      class Group
        REQUIRED_SLOTS = { item: "at least one item" }.freeze
      end

      class RadioGroup
        REQUIRED_SLOTS = { radio_item: "at least one radio item" }.freeze
      end

      class Sub
        REQUIRED_SLOTS = { trigger: "the sub-menu item", item: "at least one item" }.freeze
      end
    end
  end
end
