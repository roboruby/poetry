# frozen_string_literal: true

module Poetry
  module Ui
    module Menubar
      # The controller identifiers, declared ONCE - every data attribute
      # derives from them through the Stimulus Builder, validated against
      # the controllers manifest (no hand-written wiring strings).
      ITEM_VARIANTS = %i[default destructive].freeze
      DIRS = %i[ltr rtl].freeze

      # Shared attribute builders for the item union - mixed into Menu,
      # Sub, Group and RadioGroup so every menu level renders the same
      # anatomy through the same Builder.
      module Helpers
        private

        # menu items are role=menuitem DIVs (APG/Radix-exact) - no native
        # disabled, so aria-disabled and data-disabled are written TOGETHER.
        def apply_item_flags(attrs, inset: false, disabled: false, text_value: nil, close_on_select: nil)
          attrs["data-inset"] = "true" if inset
          if disabled
            attrs["aria-disabled"] = "true"
            attrs["data-disabled"] = ""
          end
          attrs["data-text-value"] = text_value if text_value
          attrs["data-close-on-select"] = close_on_select.to_s unless close_on_select.nil?
          attrs
        end

        # Every menu item's activation, via the public escape hatch (the
        # Component's :item declaration mirrors it).
        def item_action_attributes
          stimulus_attributes(:menu) { |menu| menu.with_action(:activate, on: :click) }
        end

        # data-slot="menubar-item-indicator" is a POETRY ADDITION
        # (new-york-v4's span is anonymous) - the self-identification rule.
        def item_indicator(icon, icon_class, kind)
          content_tag(:span, "data-slot" => "menubar-item-indicator",
                             "class" => Style.css(:item_indicator,
                                                  class: [Style.css(:item_indicator_state),
                                                          "cn-menubar-#{kind}-item-indicator"])) do
            render(Icon::Component.new(name: icon, class: icon_class))
          end
        end

        # A VISUAL keybinding hint only - poetry does not bind the key
        # (family rule), so the span is aria-hidden presentation.
        def shortcut_span(text)
          return if text.blank?

          content_tag(:span, text, "data-slot" => "menubar-shortcut", "aria-hidden" => "true",
                                   "class" => Style.css(:shortcut))
        end
      end

      # The item UNION every menu level accepts (family-identical to
      # DropdownMenu): item | checkbox_item |
      # radio_group | label | separator | group | sub - one ordered
      # collection, polymorphic setters named per part. Included by Menu,
      # Sub (recursive submenus), and Group.
      module ItemSlots
        extend ActiveSupport::Concern
        include Helpers

        included do
          renders_many :items, types: {
            item: { renders: ->(**options, &block) { item_part(**options, &block) }, as: :item },
            checkbox_item: {
              renders: ->(**options, &block) { checkbox_item_part(**options, &block) }, as: :checkbox_item
            },
            radio_group: { renders: ->(**options) { RadioGroup.new(**options) }, as: :radio_group },
            label: { renders: ->(**options, &block) { label_part(**options, &block) }, as: :label },
            separator: { renders: ->(**options) { separator_part(**options) }, as: :separator },
            group: { renders: ->(**options) { Group.new(dir: menu_dir, **options) }, as: :group },
            sub: { renders: ->(**options) { Sub.new(dir: menu_dir, **options) }, as: :sub }
          }
        end

        private

        def item_part(**options, &)
          variant = (options.delete(:variant) || :default).to_sym
          unless ITEM_VARIANTS.include?(variant)
            raise ArgumentError,
                  "unknown Menubar item variant #{variant.inspect} - known: #{ITEM_VARIANTS.join(", ")}"
          end

          shortcut = options.delete(:shortcut)
          # A link/submit item IS the interactive element (role=menuitem on the
          # <a> or <button>) - one interactive element, a11y-clean; the menu
          # controller acts through it on click + keyboard. See DropdownMenu.
          href = options.delete(:href)
          external = options.delete(:external)
          submit = options.delete(:submit)
          method = options.delete(:method)
          disabled = options[:disabled]
          attrs = {
            "data-slot" => "menubar-item", "role" => "menuitem", "tabindex" => "-1",
            "data-poetry-collection-item" => "", "data-variant" => variant,
            "class" => Style.css(:item, class: options.delete(:class))
          }.merge(item_action_attributes)
          apply_item_flags(attrs, **options.extract!(:inset, :disabled, :text_value, :close_on_select))
          content = safe_join([capture(&), shortcut_span(shortcut)].compact)

          if submit && !disabled
            # form: is RESERVED on submit items - the display:contents form
            # IS the a11y mechanism (the button is the menuitem).
            options.delete(:form)
            options.delete("form")
            return helpers.button_to(submit,
                                     { method: method || :post, form: { class: "contents" } }
                                       .merge(Poetry::Core::HTML::Attributes.merged(attrs, options))) { content }
          end

          link = href && !disabled
          if link
            attrs["href"] = href
            if external
              attrs["target"] = "_blank"
              attrs["rel"] = "noopener noreferrer"
            end
          end
          content_tag(link ? :a : :div, Poetry::Core::HTML::Attributes.merged(attrs, options)) { content }
        end

        def checkbox_item_part(**options, &block)
          checked = options.delete(:checked) || false
          shortcut = options.delete(:shortcut)
          attrs = {
            "data-slot" => "menubar-checkbox-item", "role" => "menuitemcheckbox", "tabindex" => "-1",
            "data-poetry-collection-item" => "",
            # aria-checked and the data-checked/data-unchecked pair written
            # TOGETHER, never separately.
            "aria-checked" => checked.to_s, (checked ? "data-checked" : "data-unchecked") => "",
            "class" => Style.css(:checkbox_item, class: options.delete(:class))
          }.merge(item_action_attributes)
          apply_item_flags(attrs, **options.extract!(:disabled, :text_value, :close_on_select))
          content_tag(:div, Poetry::Core::HTML::Attributes.merged(attrs, options)) do
            safe_join([item_indicator(:check, Style.css(:indicator_check), :checkbox),
                       capture(&block), shortcut_span(shortcut)].compact)
          end
        end

        def label_part(inset: false, **options, &block)
          attrs = {
            "data-slot" => "menubar-label",
            "class" => Style.css(:label, class: options.delete(:class))
          }
          attrs["data-inset"] = "true" if inset
          content_tag(:div, Poetry::Core::HTML::Attributes.merged(attrs, options)) { capture(&block) }
        end

        def separator_part(**options)
          attrs = {
            "data-slot" => "menubar-separator", "role" => "separator",
            "aria-orientation" => "horizontal",
            "class" => Style.css(:separator, class: options.delete(:class))
          }
          content_tag(:div, nil, Poetry::Core::HTML::Attributes.merged(attrs, options))
        end
      end

      # The menus-family sibling (Menubar): a desktop-app
      # command bar - role=menubar, ONE tab stop (horizontal roving focus
      # across role=menuitem triggers), each menu a full family popup on its
      # own poetry--core--menu instance (modal: false - hover-slide needs
      # the sibling triggers pressable while a menu is open). The thin
      # poetry--core--menubar coordinator owns value + toggle/hover-slide/
      # edge-navigate; everything heavier stays in the shared primitives.
      class Component < Poetry::Core::Component
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

        # required: the hand raise in before_render carries the message;
        # the flag carries the fact to the registry (: the floating
        # crash - a required option the static tier could not see).
        option :label, :string, required: true
        option :loop, :boolean, default: false
        option :value, :string
        option :dir, :symbol

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
               "data-value" => "the radio's value"
             }
        part "menubar-item-indicator", "The check/circle glyph slot inside checkbox and radio items - " \
                                       "state rides the parent item; the glyph stays decorative"
        part "menubar-separator", "role=separator rule between groups"
        part "menubar-shortcut", "The trailing keybinding HINT - aria-hidden, never binds the key"
        part "menubar-sub", "A submenu scope - hosts its own popper around the sub trigger/content pair"
        part "menubar-sub-trigger", "The role=menuitem row opening its submenu",
             states: {
               "data-popup-open" => "its submenu is open (written with aria-expanded; absence is the " \
                                    "closed state)"
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

        renders_many :menus, ->(**options) { Menu.new(bar: self, dir: dir, **options) }

        def before_render
          # The the base contract base-contract borrow: the bar's accessible name is
          # not optional (APG - a page may hold more than one menubar).
          raise ArgumentError, "Menubar requires label: (the bar's accessible name)" if label.blank?
          raise ArgumentError, "Menubar requires at least one with_menu" unless menus?
        end

        def value_string = value.to_s

        def root_attributes
          root = {
            "data-slot" => "menubar", "role" => "menubar", "aria-label" => label,
            # The bar ROOT keeps the open/closed pair (W1 resolution: Base UI
            # has no bar-root state attr - poetry keeps the mounted pair).
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
        def tab_stop?(menu)
          tab_stop_menu.equal?(menu)
        end

        def open_menu?(menu_value)
          value.present? && value.to_s == menu_value
        end

        # Registers a Menu part and hands back its 1-based position (the
        # default value: "menu-<position>").
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
      end

      # One logical menu: the trigger + content pair. Radix renders no
      # element here; poetry hosts the pair's poetry--core--menu +
      # poetry--core--popper controllers on a display:contents wrapper
      # (out of the bar's flex layout AND the accessibility tree), keeping
      # the rendered semantics Radix-parity. Plain ViewComponent::Base ON
      # PURPOSE - the nested parts are anatomy, not registry components.
      class Menu < Poetry::Core::Component
        internal_component!
        include ItemSlots

        attr_reader :value, :disabled

        def initialize(bar:, value: nil, disabled: false, dir: nil, **extra_attributes)
          super(extra_attributes)
          @bar = bar
          @disabled = disabled
          @dir = dir
          position = @bar.register_menu(self)
          @value = (value || "menu-#{position}").to_s
        end

        # The top-level trigger DELTA: a real button that is role=menuitem
        # INSIDE role=menubar (vs DropdownMenu's plain menu button), wired
        # to the COORDINATOR (toggle / gated hover-slide / keyboard open).
        renders_one :trigger, lambda { |**options, &block|
          attrs = {
            "type" => "button", "id" => trigger_id, "data-slot" => "menubar-trigger",
            "role" => "menuitem", "tabindex" => @bar.tab_stop?(self) ? "0" : "-1",
            "data-poetry-collection-item" => "",
            "aria-haspopup" => "menu", "aria-expanded" => open?.to_s, "aria-controls" => content_id,
            "data-value" => value,
            "class" => Style.css(:trigger, class: options.delete(:class))
          }.merge(trigger_stimulus_attributes)
          # Base UI trigger state: bare data-popup-open while open, NO
          # attribute while closed (absence IS the state).
          attrs["data-popup-open"] = "" if open?
          if disabled
            attrs["disabled"] = true
            attrs["data-disabled"] = ""
          end
          content_tag(:button, Poetry::Core::HTML::Attributes.merged(attrs, options)) { capture(&block) }
        }

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
        # positioning overrides (align start / alignOffset -4 / sideOffset
        # 8, source-validated).
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

      # role=group semantic grouping between separators - the same item
      # union, one level down.
      class Group < Poetry::Core::Component
        internal_component!
        include ItemSlots

        def initialize(dir: nil, **extra_attributes)
          super(extra_attributes)
          @dir = dir
        end

        def before_render
          raise ArgumentError, "Menubar group requires at least one item" unless items?
        end

        def call
          attrs = { "data-slot" => "menubar-group", "role" => "group" }
          content_tag(:div, Poetry::Core::HTML::Attributes.merged(attrs, html_attributes)) { safe_join(items.map(&:to_s)) }
        end

        private

        def menu_dir
          @dir
        end
      end

      # role=group scoping the single-select value for its radio items.
      # Duplicate radio values raise ArgumentError at render (the base-contract
      # base contract); radio items exist ONLY through this group.
      class RadioGroup < Poetry::Core::Component
        internal_component!
        include Helpers

        attr_reader :group_value

        def initialize(value: nil, **extra_attributes)
          super(extra_attributes)
          @group_value = value&.to_s
          @seen_values = Set.new
        end

        renders_many :radio_items, lambda { |value:, disabled: false, text_value: nil,
                                            close_on_select: nil, shortcut: nil, **options, &block|
          key = value.to_s
          unless @seen_values.add?(key)
            raise ArgumentError, "duplicate Menubar radio value #{key.inspect} - values must be " \
                                 "unique within their radio group"
          end

          checked = !group_value.nil? && key == group_value
          attrs = {
            "data-slot" => "menubar-radio-item", "role" => "menuitemradio", "tabindex" => "-1",
            "data-poetry-collection-item" => "", "data-value" => key,
            "aria-checked" => checked.to_s, (checked ? "data-checked" : "data-unchecked") => "",
            "class" => Style.css(:radio_item, class: options.delete(:class))
          }.merge(item_action_attributes)
          apply_item_flags(attrs, disabled:, text_value:, close_on_select:)
          content_tag(:div, Poetry::Core::HTML::Attributes.merged(attrs, options)) do
            safe_join([item_indicator(:circle, Style.css(:indicator_circle), :radio),
                       capture(&block), shortcut_span(shortcut)].compact)
          end
        }

        def before_render
          raise ArgumentError, "Menubar radio group requires at least one with_radio_item" unless radio_items?
        end

        def call
          attrs = { "data-slot" => "menubar-radio-group", "role" => "group" }
          attrs["data-value"] = group_value if group_value
          content_tag(:div, Poetry::Core::HTML::Attributes.merged(attrs, html_attributes)) { safe_join(radio_items.map(&:to_s)) }
        end
      end

      # A submenu scope: its own popper instance (sub_trigger = anchor,
      # sub_content = content; side flips under RTL) around the same item
      # union, recursively - family-identical to DropdownMenu's.
      class Sub < Poetry::Core::Component
        internal_component!
        include ItemSlots

        def initialize(dir: nil, **extra_attributes)
          super(extra_attributes)
          @dir = dir
        end

        renders_one :trigger, lambda { |inset: false, disabled: false, text_value: nil, **options, &block|
          attrs = {
            "id" => trigger_id, "data-slot" => "menubar-sub-trigger", "role" => "menuitem",
            "tabindex" => "-1", "data-poetry-collection-item" => "",
            "aria-haspopup" => "menu", "aria-expanded" => "false", "aria-controls" => content_id,
            "class" => Style.css(:sub_trigger, class: options.delete(:class))
          }.merge(sub_trigger_stimulus_attributes)
          apply_item_flags(attrs, inset:, disabled:, text_value:)
          content_tag(:div, Poetry::Core::HTML::Attributes.merged(attrs, options)) do
            safe_join([capture(&block), chevron])
          end
        }

        def before_render
          raise ArgumentError, "Menubar sub requires with_trigger (the sub-menu item)" unless trigger?
          raise ArgumentError, "Menubar sub requires at least one item" unless items?
        end

        def call
          content_tag(:div, sub_attributes) { safe_join([trigger, sub_content]) }
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

        def rtl?
          @dir == :rtl
        end

        def instance_id
          @instance_id ||= poetry_instance_id("poetry-menubar-sub")
        end

        def sub_attributes
          attrs = { "data-slot" => "menubar-sub" }.merge(
            stimulus_attributes(:popper) do |popper|
              popper.register_controller
              popper.with_value(:side, rtl? ? :left : :right)
              popper.with_value(:align, :start)
            end
          )
          Poetry::Core::HTML::Attributes.merged(attrs, html_attributes)
        end

        def sub_content
          attrs = {
            "id" => content_id, "role" => "menu", "aria-orientation" => "vertical",
            "aria-labelledby" => trigger_id, "tabindex" => "-1",
            "data-slot" => "menubar-sub-content", "data-closed" => "", "hidden" => true,
            "class" => Style.css(:sub_content)
          }.merge(stimulus_attributes(:popper) { |popper| popper.with_target(:content) })
          content_tag(:div, attrs) { safe_join(items.map(&:to_s)) }
        end

        def sub_trigger_stimulus_attributes
          stimulus_attributes(:menu, :popper) do |menu, popper|
            menu.with_action(:sub_enter, on: :pointerenter)
            menu.with_action(:sub_leave, on: :pointerleave)
            menu.with_action(:open_sub, on: :click)
            popper.with_target(:anchor)
          end
        end

        def chevron
          render(Icon::Component.new(name: :"chevron-right", class: Style.css(:sub_indicator)))
        end
      end

      # The builder classes behind lambda-wrapped slots: a lambda
      # hides its return class from introspection, so the owners declare
      # them and the registry walker recurses into each builder's own call
      # surface (with_menu yields a Menu; with_sub a Sub). REQUIRED_SLOTS
      # states the same facts the before_render raises enforce, so
      # poetry check flags the omission without rendering (the menu
      # crash: with_trigger left out, four truthful checks silent).
      class Component
        SLOT_BUILDERS = { menu: Menu }.freeze
        REQUIRED_SLOTS = { menu: "at least one menu" }.freeze
      end

      class Menu
        REQUIRED_SLOTS = { trigger: "the top-level menu button", item: "at least one item" }.freeze
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

      module ItemSlots
        SLOT_BUILDERS = { sub: Sub, group: Group, radio_group: RadioGroup }.freeze
      end
    end
  end
end
