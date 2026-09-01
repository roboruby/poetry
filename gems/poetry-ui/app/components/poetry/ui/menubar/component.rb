# frozen_string_literal: true

module Poetry
  module Ui
    # A desktop-style menu bar of drop-down menus.
    module Menubar
      # Shared vocabularies, declared once at module level so the root
      # Component and the nested menu-level classes read the same lists.
      DIRS = %i[ltr rtl].freeze

      # The shared menus-family helpers plus this family's fork: Menubar
      # themes its checkbox and radio indicators separately (a per-kind
      # class rides along).
      #
      # @api private
      module Helpers
        include Poetry::Ui::Menus::Helpers

        private

        def indicator_extra_class(kind)
          "cn-menubar-#{kind}-item-indicator"
        end
      end

      # The shared menus-family item slots wearing this family's identity -
      # SLOT_BUILDERS (reopened at the bottom, once the classes exist) keeps
      # the registry recursion on the family classes.
      #
      # @api private
      module ItemSlots
        extend ActiveSupport::Concern
        include Poetry::Ui::Menus::ItemSlots
        include Helpers
      end

      # A desktop-app command bar: File / Edit / View menus on one
      # role=menubar row. The bar is a single tab stop - arrow keys move
      # between the top-level triggers - and each trigger opens a full
      # drop-down menu (action items, checkbox and radio rows, submenus,
      # separators, shortcut hints). Menus are non-modal, so once one is
      # open, hovering a sibling trigger slides to its menu.
      #
      # label: (the bar's accessible name) and at least one with_menu are
      # required. For site navigation use NavigationMenu; for a single
      # actions menu use DropdownMenu.
      #
      # @example An application command bar
      #   render Poetry::Ui::Menubar::Component.new(label: "Application") do |bar|
      #     bar.with_menu do |menu|
      #       menu.with_trigger { "File" }
      #       menu.with_item(shortcut: "⌘N") { "New" }
      #       menu.with_separator
      #       menu.with_item { "Print..." }
      #     end
      #   end
      class Component < Poetry::Core::Component
        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Use poetry_menubar for app-chrome command menus ONLY - site navigation is NavigationMenu " \
          "(untrapped), a single actions menu is DropdownMenu.",
          "label: is REQUIRED (the bar's accessible name).",
          "Never put non-menuitem interactive elements directly in the bar (breaks roving focus + APG " \
          "roles) - a Toolbar is the component for mixed controls.",
          "shortcut: is a visual hint ONLY - it does not register a keybinding; wire real shortcuts " \
          "separately.",
          "Do not hand-wire hover-open-from-cold; hover only slides between menus once one is open " \
          "(the gated-hover rule).",
          "In-menu item rules (destructive variant, inset, checkbox/radio) follow the DropdownMenu " \
          "family contract."
        ].freeze

        renders_many :menus,
                     doc: "The top-level menus. Each takes with_trigger (the menu button) plus the family item " \
                          "slots (with_item, with_checkbox_item, with_radio_group, with_sub, with_separator, ...); " \
                          "value: defaults to the menu's position.",
                     renders: ->(**options) { Menu.new(bar: self, dir: dir, **options) }

        use_stimulus do
          on :root do
            controller :menubar do
              register
              value :value, from: :value_string
              value :loop
              # The coordinator's two event seams: the family menu
              # controller's edge-navigate (cross-menu arrows) and closed
              # (value bookkeeping) - custom poetry:-namespaced events.
              action :slide_adjacent, on: "poetry:menu:edge-navigate"
              action :on_menu_closed, on: "poetry:menu:closed"
            end
            controller :roving_focus do
              register
              # The DELTA vs in-menu roving: horizontal, manageTabindex
              # TRUE (one tab stop for the whole bar).
              value :orientation, :horizontal
              value :manage_tabindex, true
              value :loop
              action :keydown, on: :keydown
            end
          end
          # Anatomy-rendered wiring (the Menu/Sub classes build via the
          # escape hatch; declared here for the contract).
          on :menu_wrapper do
            controller :menu do
              register
              value :open
              value :modal, false
            end
            controller :popper do
              register
              value :side, :bottom
              value :align, :start
              value :side_offset, 8
              value :align_offset, -4
              value :avoid_collisions, true
            end
          end
          on :trigger do
            controller :menubar do
              action :toggle, on: :pointerdown
              action :hover_slide, on: :pointerenter
              action :trigger_keydown, on: :keydown
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

        option :label, :string, required: true,
                                doc: "The bar's accessible name - a page may hold more than one menubar."
        option :loop, :boolean, default: false, doc: "Wraps arrow-key movement past either end of the bar."
        option :value, :string,
               doc: "Server-renders the menu with this value open (values default to \"menu-<position>\")."
        option :dir, :symbol, doc: "The reading direction; :rtl flips arrow-key movement and submenu sides."

        validates :dir, inclusion: { in: DIRS }, allow_nil: true

        part "menubar", "The role=menubar bar - one horizontal roving tab stop across the triggers",
             states: {
               "data-open" => "some menu is open (value present; the coordinator flips the pair)",
               "data-closed" => "no menu is open"
             }
        part "menubar-menu", "One logical menu - a display:contents wrapper hosting the trigger + " \
                             "content pair's menu and popper controllers"
        part "menubar-trigger", "The top-level menu button - a role=menuitem INSIDE the bar",
             states: {
               "data-value" => "the menu's value - the coordinator's open/close key",
               "data-popup-open" => "its menu is open (written with aria-expanded; absence is the " \
                                    "closed state)",
               "data-disabled" => "trigger is disabled (written together with the disabled property)"
             }
        part "menubar-content", "The role=menu popup panel - positioning, animation, and the open " \
                                "state ride here",
             states: {
               "data-open" => "menu is open (presence flips the pair at runtime)",
               "data-closed" => "menu is closed or animating out (the server-rendered state)",
               "data-side" => { condition: "the placement side (bottom initially; popper re-writes it " \
                                           "after collision flips)",
                                values: %w[top right bottom left] },
               "data-align" => { condition: "the alignment against the trigger (start initially; popper " \
                                            "re-resolves it)",
                                 values: %w[start center end] }
             },
             vars: {
               "--transform-origin" => "popper's anchor-facing animation origin",
               "--available-width" => "popper: viewport space left for the panel (post-flip)",
               "--available-height" => "popper: viewport space left for the panel (post-flip)",
               "--anchor-width" => "popper: the trigger's measured width",
               "--anchor-height" => "popper: the trigger's measured height"
             }
        part "menubar-group", "role=group semantic grouping between separators"
        part "menubar-label", "Non-interactive heading for a run of items",
             states: {
               "data-inset" => "indented to align with checkbox/radio item text (inset: true)"
             }
        part "menubar-item", "One role=menuitem action row",
             states: {
               "data-variant" => "default or destructive (the danger treatment)",
               "data-inset" => "indented to align with checkbox/radio item text (inset: true)",
               "data-disabled" => "item is disabled (always written together with aria-disabled)"
             }
        part "menubar-checkbox-item", "A role=menuitemcheckbox toggle row",
             states: {
               "data-checked" => "checked (the controller re-writes the pair with aria-checked on " \
                                 "activation)",
               "data-unchecked" => "unchecked",
               "data-disabled" => "item is disabled (always written together with aria-disabled)",
               "data-close-on-select" => "per-item override of the menu's close-on-select default " \
                                         "(\"false\" keeps the menu open)"
             }
        part "menubar-radio-group", "role=group scoping one single-select value",
             states: {
               "data-value" => "the selected radio value (the controller re-writes it on change)"
             }
        part "menubar-radio-item", "A role=menuitemradio row inside a radio group",
             states: {
               "data-checked" => "the selected radio (the controller re-writes the pair with aria-checked)",
               "data-unchecked" => "not selected",
               "data-value" => "the radio's value",
               "data-disabled" => "item is disabled (always written together with aria-disabled)"
             }
        part "menubar-checkbox-item-indicator", "The check glyph slot inside checkbox items - " \
                                                "aria-hidden; the item's aria-checked/data-checked pair carries state"
        part "menubar-radio-item-indicator", "The circle glyph slot inside radio items - aria-hidden; " \
                                             "the item's aria-checked/data-checked pair carries state"
        part "menubar-separator", "role=separator rule between groups"
        part "menubar-shortcut", "The trailing keybinding HINT - aria-hidden, never binds the key"
        part "menubar-sub", "A submenu scope - hosts its own popper around the sub trigger/content pair"
        part "menubar-sub-trigger", "The role=menuitem row opening its submenu",
             states: {
               "data-popup-open" => "its submenu is open (written with aria-expanded; absence is the " \
                                    "closed state)",
               "data-inset" => "indented to align with checkbox/radio item text (inset: true)"
             }
        part "menubar-sub-content", "The nested role=menu panel - its own popper content on the same " \
                                    "presence machinery",
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

        # Enforces the required label and menu slots.
        # @api private
        def before_render
          # The bar's accessible name is not optional - a page may hold
          # more than one menubar.
          raise ArgumentError, "Menubar requires label: (the bar's accessible name)" if label.blank?
          raise ArgumentError, "Menubar requires at least one with_menu" unless menus?
        end

        # @api private
        def value_string = value.to_s

        # @api private
        def root_attributes
          root = {
            "data-slot" => "menubar", "role" => "menubar", "aria-label" => label,
            # The bar ROOT keeps the open/closed pair so themes can key
            # on bar-wide state.
            (value.present? ? "data-open" : "data-closed") => ""
          }
          root["dir"] = dir.to_s if dir
          html_attributes.merge_if_not_set(
            root.merge(stimulus_attributes_for(:root)).merge(component_data_attributes)
          )
        end

        # The bar-level tab stop is server-rendered (exactly one tabindex=0
        # before any JS): the open menu's trigger when value: matches,
        # otherwise the first enabled trigger.
        # @api private
        def tab_stop?(menu)
          tab_stop_menu.equal?(menu)
        end

        # @api private
        def open_menu?(menu_value)
          value.present? && value.to_s == menu_value
        end

        # Registers a Menu part and hands back its 1-based position (the
        # default value: "menu-<position>").
        # @api private
        def register_menu(menu)
          menu_parts << menu
          menu_parts.size
        end

        private

        def menu_parts
          @menu_parts ||= []
        end

        def tab_stop_menu
          menu_parts.find { |menu| open_menu?(menu.value) && !menu.disabled } ||
            menu_parts.find { |menu| !menu.disabled } || menu_parts.first
        end

        private :value_string, :root_attributes
      end

      # One logical menu: the trigger + content pair, hosted on a
      # display:contents wrapper that its behavior wiring rides - erased
      # from the bar's flex layout AND the accessibility tree, so the
      # rendered semantics stay a flat menubar. The nested parts are
      # anatomy, not registry components.
      #
      # @api private
      class Menu < Poetry::Core::Component
        internal_component!
        include ItemSlots

        attr_reader :value, :disabled

        renders_one :trigger,
                    doc: "The top-level menu button: a real button that is role=menuitem INSIDE role=menubar, wired " \
                         "to the bar coordinator (toggle / gated hover-slide / keyboard open).",
                    renders: lambda { |**options, &block|
                      attrs = {
                        "type" => "button", "id" => trigger_id, "data-slot" => "menubar-trigger",
                        "role" => "menuitem", "tabindex" => @bar.tab_stop?(self) ? "0" : "-1",
                        "data-poetry-collection-item" => "",
                        "aria-haspopup" => "menu", "aria-expanded" => open?.to_s, "aria-controls" => content_id,
                        "data-value" => value,
                        "class" => Style.css(:trigger, class: options.delete(:class))
                      }.merge(trigger_stimulus_attributes)
                      # Trigger open state: bare data-popup-open while open, NO
                      # attribute while closed (absence IS the state).
                      attrs["data-popup-open"] = "" if open?
                      if disabled
                        attrs["disabled"] = true
                        attrs["data-disabled"] = ""
                      end
                      content_tag(:button, Poetry::Core::HTML::Attributes.merged(attrs, options)) { capture(&block) }
                    }

        def initialize(bar:, value: nil, disabled: false, dir: nil, **extra_attributes)
          super(extra_attributes)
          @bar = bar
          @disabled = disabled
          @dir = dir
          position = @bar.register_menu(self)
          @value = (value || "menu-#{position}").to_s
        end

        def before_render
          raise ArgumentError, "Menubar menu requires with_trigger (the top-level menu button)" unless trigger?
          raise ArgumentError, "Menubar menu requires at least one item" unless items?
        end

        def call
          content_tag(:div, menu_attributes) { safe_join([trigger, menu_content]) }
        end

        def open?
          @bar.open_menu?(value)
        end

        def trigger_id
          "#{instance_id}-trigger"
        end

        def content_id
          "#{instance_id}-content"
        end

        private

        def menu_dir
          @dir
        end

        def instance_id
          @instance_id ||= poetry_instance_id("poetry-menubar")
        end

        # The per-menu machinery scope: the family menu controller (modal
        # FALSE - the bar's hover-slide needs sibling triggers pressable,
        # so no body scrim / no trap) + its popper with the menubar
        # positioning overrides (align start / alignOffset -4 / sideOffset 8).
        def menu_attributes
          wiring = stimulus_attributes(:menu, :popper) do |menu, popper|
            menu.register_controller
            menu.with_value(:open, open?)
            menu.with_value(:modal, false)
            popper.register_controller
            popper.with_value(:side, :bottom)
            popper.with_value(:align, :start)
            popper.with_value(:side_offset, 8)
            popper.with_value(:align_offset, -4)
            popper.with_value(:avoid_collisions, true)
          end
          { "data-slot" => "menubar-menu", "class" => Style.css(:menu) }
            .merge(wiring).then { |w| Poetry::Core::HTML::Attributes.merged(w, html_attributes) }
        end

        def trigger_stimulus_attributes
          stimulus_attributes(:menubar, :popper) do |menubar, popper|
            menubar.with_action(:toggle, on: :pointerdown)
            menubar.with_action(:hover_slide, on: :pointerenter)
            menubar.with_action(:trigger_keydown, on: :keydown)
            popper.with_target(:anchor)
          end
        end

        # NOT named `content` - that would shadow ViewComponent's own slot
        # content accessor and recurse through the slot machinery.
        def menu_content
          attrs = {
            "id" => content_id, "role" => "menu", "aria-orientation" => "vertical",
            "aria-labelledby" => trigger_id, "tabindex" => "-1",
            "data-slot" => "menubar-content", (open? ? "data-open" : "data-closed") => "",
            # Initial placement, re-resolved live by popper on open.
            "data-side" => "bottom", "data-align" => "start",
            "class" => Style.css(:content)
          }.merge(stimulus_attributes(:popper) { |popper| popper.with_target(:content) })
          attrs["hidden"] = true unless open?
          content_tag(:div, attrs) { safe_join(items.map(&:to_s)) }
        end
      end

      # role=group semantic grouping between separators - the shared
      # menus-family anatomy wearing this family's identity.
      #
      # @api private
      class Group < Poetry::Ui::Menus::Group
        include ItemSlots
      end

      # role=group scoping the single-select value for its radio items -
      # the shared menus-family anatomy wearing this family's identity.
      #
      # @api private
      class RadioGroup < Poetry::Ui::Menus::RadioGroup
        include Helpers
      end

      # A submenu scope (the full item vocabulary again, on its own
      # positioned panel) - the shared menus-family anatomy wearing this
      # family's identity.
      #
      # @api private
      class Sub < Poetry::Ui::Menus::Sub
        include ItemSlots
      end

      # The builder classes behind lambda-wrapped slots: a lambda
      # hides its return class from introspection, so the owners declare
      # them and the registry walker recurses into each builder's own call
      # surface (with_menu yields a Menu; with_sub a Sub). REQUIRED_SLOTS
      # states the same facts the before_render raises enforce, so static
      # checks flag an omission without rendering.
      class Component
        # Maps slot names to the classes their builder lambdas return.
        SLOT_BUILDERS = { menu: Menu }.freeze
        # Slots the component cannot render without; static checks read this without rendering.
        REQUIRED_SLOTS = { menu: "at least one menu" }.freeze
      end

      class Menu
        # Slots this menu cannot render without.
        REQUIRED_SLOTS = { trigger: "the top-level menu button", item: "at least one item" }.freeze
      end

      class Group
        # Slots this group cannot render without.
        REQUIRED_SLOTS = { item: "at least one item" }.freeze
      end

      class RadioGroup
        # Slots this radio group cannot render without.
        REQUIRED_SLOTS = { radio_item: "at least one radio item" }.freeze
      end

      class Sub
        # Slots this submenu cannot render without.
        REQUIRED_SLOTS = { trigger: "the sub-menu item", item: "at least one item" }.freeze
      end

      module ItemSlots
        # Maps nested slot names to the classes their builder lambdas return.
        SLOT_BUILDERS = { sub: Sub, group: Group, radio_group: RadioGroup }.freeze
      end
    end
  end
end
