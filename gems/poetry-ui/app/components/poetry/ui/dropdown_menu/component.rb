# frozen_string_literal: true

module Poetry
  module Ui
    # The DropdownMenu family - the button-triggered action menu.
    module DropdownMenu
      # The closed vocabulary for the side placement axis.
      SIDES = %i[top right bottom left].freeze
      # The closed vocabulary for the align placement axis.
      ALIGNS = %i[start center end].freeze
      # The closed vocabulary for the dir (reading direction) axis.
      DIRS = %i[ltr rtl].freeze

      # The shared menus item union wearing this family's identity -
      # SLOT_BUILDERS is added in a reopen at the bottom of the file,
      # once the family classes it names exist.
      module ItemSlots
        extend ActiveSupport::Concern
        include Poetry::Ui::Menus::ItemSlots
      end

      # A dropdown menu: a button that opens a popup list of actions
      # (role=menu), composed from items, checkbox items, radio groups,
      # labels, separators, groups, and nested submenus. Reach for it
      # when one control offers several actions; choosing a form VALUE
      # belongs to Select or Combobox instead.
      #
      # Requires with_trigger (the menu button) and at least one item.
      # Arrow-key navigation, typeahead, and focus containment activate
      # when the menu opens; the closed menu renders inert and hidden.
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

        # Projected into the registry, llms.txt, and the agent surface.
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

        # Slot-to-component map: with_trigger renders a Button, so callers
        # get Button's full option and slot contract on the trigger.
        SLOT_RENDERS = { trigger: Button::Component }.freeze

        renders_one :trigger,
                    doc: "The menu button - a poetry Button (options forward to it, e.g. variant: :outline). The " \
                         "slot owns the aria-haspopup/expanded/ controls wiring regardless of the composed content, " \
                         "so composition cannot drop the aria.",
                    renders: lambda { |**options, &block|
                      wiring = {
                        "id" => trigger_id, "data-slot" => "dropdown-menu-trigger",
                        "aria-haspopup" => "menu", "aria-expanded" => open.to_s, "aria-controls" => content_id
                      }.merge(stimulus_attributes_for(:trigger))
                      # Trigger state: bare data-popup-open while open, NO attribute
                      # while closed (absence IS the state).
                      wiring["data-popup-open"] = "" if open
                      composed_trigger(wiring, options, &block) || begin
                        options[:disabled] = true if disabled && !options.key?(:disabled)
                        Button::Component.new(**wiring, **options, &block)
                      end
                    }

        # The content's layer behaviors (focus containment, dismissal,
        # roving focus) are attached by the menu controller on open rather
        # than declared statically here - a statically-connected focus
        # trap on a hidden menu would steal focus at page load.
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

        option :open, :boolean, default: false, doc: "Renders the menu already open on page load."
        option :modal, :boolean, default: true,
                                 doc: "While open, pointer interaction outside the menu is blocked; false keeps the " \
                                      "rest of the page interactive."
        option :side, :symbol, default: :bottom,
                               doc: "Which side of the trigger the menu opens on (flips on collision)."
        option :align, :symbol, default: :center, doc: "The menu's alignment against the trigger's edge."
        option :side_offset, :integer, default: 4, doc: "Gap in pixels between the trigger and the menu."
        option :align_offset, :integer, default: 0, doc: "Pixel shift along the alignment edge."
        option :avoid_collisions, :boolean, default: true,
                                            doc: "Flips/shifts placement to keep the menu inside the viewport."
        option :loop, :boolean, default: false, doc: "Arrow-key navigation wraps from the last item back to the first."
        option :dir, :symbol, doc: "Reading direction; :rtl flips submenu sides and indicators."
        option :disabled, :boolean, default: false, doc: "Disables the menu trigger button."

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
               "data-value" => "the radio's value",
               "data-disabled" => "item is disabled (always written together with aria-disabled)"
             }
        part "dropdown-menu-checkbox-item-indicator",
             "The check glyph inside checkbox items (aria-hidden; the item carries the checked state)"
        part "dropdown-menu-radio-item-indicator",
             "The circle glyph inside radio items (aria-hidden; the item carries the checked state)"
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

        # Enforces the required slots before render.
        # @api private
        def before_render
          raise ArgumentError, "DropdownMenu requires with_trigger (the menu button)" unless trigger?
          raise ArgumentError, "DropdownMenu requires at least one item" unless items?
        end

        # The trigger element's server-stable id.
        # @api private
        def trigger_id
          "#{instance_id}-trigger"
        end

        # The content element's server-stable id (aria-controls target).
        # @api private
        def content_id
          "#{instance_id}-content"
        end

        # The root wrapper's attributes.
        # @api private
        def root_attributes
          root = { "data-slot" => "dropdown-menu" }
          root["dir"] = dir.to_s if dir
          html_attributes.merge_if_not_set(
            root.merge(stimulus_attributes_for(:root)).merge(component_data_attributes)
          )
        end

        # The role=menu panel's attributes.
        # @api private
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

        private :trigger_id, :content_id, :root_attributes, :content_attributes
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

      # The builder classes behind lambda-wrapped slot types: a lambda
      # hides its return class from introspection, so the owner declares
      # it and the registry walker recurses into the builder's own call
      # surface (with_sub yields a Sub with its own items).
      module ItemSlots
        # Nested-slot recursion map for the registry projection.
        SLOT_BUILDERS = { sub: Sub, group: Group, radio_group: RadioGroup }.freeze
      end

      class Component
        # The slots before_render enforces, stated statically for render-free checks.
        REQUIRED_SLOTS = { trigger: "the menu button", item: "at least one item" }.freeze
      end

      class Group
        # The slots before_render enforces, stated statically for render-free checks.
        REQUIRED_SLOTS = { item: "at least one item" }.freeze
      end

      class RadioGroup
        # The slots before_render enforces, stated statically for render-free checks.
        REQUIRED_SLOTS = { radio_item: "at least one radio item" }.freeze
      end

      class Sub
        # The slots before_render enforces, stated statically for render-free checks.
        REQUIRED_SLOTS = { trigger: "the sub-menu item", item: "at least one item" }.freeze
      end
    end
  end
end
