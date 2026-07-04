# frozen_string_literal: true

module Poetry
  module Ui
    module Menubar
      # The controller identifiers, declared ONCE - every data attribute
      # derives from them through the Stimulus Builder, validated against
      # the controllers manifest (no hand-written wiring strings).
      MENUBAR = %i[poetry core menubar].freeze
      ROVING = %i[poetry core roving_focus].freeze
      MENU = %i[poetry core menu].freeze
      POPPER = %i[poetry core popper].freeze
      ITEM_VARIANTS = %i[default destructive].freeze
      DIRS = %i[ltr rtl].freeze

      # Shared attribute builders for the item union - mixed into Menu,
      # Sub, Group and RadioGroup so every menu level renders the same
      # anatomy through the same Builder.
      module Helpers
        private

        def menu_stimulus
          attrs = Poetry::Core::HTML::Attributes.new
          yield Poetry::Core::Stimulus::Builder.new(MENU, attrs)
          attrs.to_attributes
        end

        def popper_stimulus
          attrs = Poetry::Core::HTML::Attributes.new
          yield Poetry::Core::Stimulus::Builder.new(POPPER, attrs)
          attrs.to_attributes
        end

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

        def item_action_attributes
          menu_stimulus { |menu| menu.with_action(:activate, on: :click) }
        end

        # data-slot="menubar-item-indicator" is a POETRY ADDITION
        # (new-york-v4's span is anonymous) - the self-identification rule.
        def item_indicator(icon, icon_class)
          content_tag(:span, "data-slot" => "menubar-item-indicator",
                             "class" => Style.css(:item_indicator, class: Style.css(:item_indicator_state))) do
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

        def item_part(**options, &block)
          variant = (options.delete(:variant) || :default).to_sym
          unless ITEM_VARIANTS.include?(variant)
            raise ArgumentError,
                  "unknown Menubar item variant #{variant.inspect} - known: #{ITEM_VARIANTS.join(", ")}"
          end

          shortcut = options.delete(:shortcut)
          attrs = {
            "data-slot" => "menubar-item", "role" => "menuitem", "tabindex" => "-1",
            "data-poetry-collection-item" => "", "data-variant" => variant,
            "class" => Style.css(:item, class: options.delete(:class))
          }.merge(item_action_attributes)
          apply_item_flags(attrs, **options.extract!(:inset, :disabled, :text_value, :close_on_select))
          content_tag(:div, attrs.merge(options)) do
            safe_join([capture(&block), shortcut_span(shortcut)].compact)
          end
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
          content_tag(:div, attrs.merge(options)) do
            safe_join([item_indicator(:check, Style.css(:indicator_check)),
                       capture(&block), shortcut_span(shortcut)].compact)
          end
        end

        def label_part(inset: false, **options, &block)
          attrs = {
            "data-slot" => "menubar-label",
            "class" => Style.css(:label, class: options.delete(:class))
          }
          attrs["data-inset"] = "true" if inset
          content_tag(:div, attrs.merge(options)) { capture(&block) }
        end

        def separator_part(**options)
          attrs = {
            "data-slot" => "menubar-separator", "role" => "separator",
            "aria-orientation" => "horizontal",
            "class" => Style.css(:separator, class: options.delete(:class))
          }
          content_tag(:div, nil, attrs.merge(options))
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

        option :label, :string
        option :loop, :boolean, default: false
        option :value, :string
        option :dir, :symbol

        validates :dir, inclusion: { in: DIRS }, allow_nil: true

        renders_many :menus, ->(**options) { Menu.new(bar: self, dir: dir, **options) }

        def before_render
          # The the base contract base-contract borrow: the bar's accessible name is
          # not optional (APG - a page may hold more than one menubar).
          raise ArgumentError, "Menubar requires label: (the bar's accessible name)" if label.blank?
          raise ArgumentError, "Menubar requires at least one with_menu" unless menus?
        end

        def root_attributes
          root = {
            "data-slot" => "menubar", "role" => "menubar", "aria-label" => label,
            # The bar ROOT keeps the open/closed pair (W1 resolution: Base UI
            # has no bar-root state attr - poetry keeps the mounted pair).
            (value.present? ? "data-open" : "data-closed") => ""
          }
          root["dir"] = dir.to_s if dir
          html_attributes.merge_if_not_set(
            root.merge(root_stimulus_attributes).merge(component_data_attributes)
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

        # BOTH bar controllers build into ONE Attributes instance - a plain
        # Hash#merge would overwrite data-controller instead of
        # token-concatenating it (the Accordion lesson).
        def root_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          menubar = Poetry::Core::Stimulus::Builder.new(MENUBAR, attrs)
          menubar.register_controller
          menubar.with_value(:value, value.to_s)
          menubar.with_value(:loop, loop)
          # The coordinator's two event seams: the family menu controller's
          # edge-navigate (cross-menu arrows) and closed (value bookkeeping).
          menubar.with_action(:slide_adjacent, on: "poetry:menu:edge-navigate")
          menubar.with_action(:on_menu_closed, on: "poetry:menu:closed")
          roving = Poetry::Core::Stimulus::Builder.new(ROVING, attrs)
          roving.register_controller
          # The DELTA vs the in-menu roving: horizontal, manageTabindex TRUE
          # (one tab stop for the whole bar - the inverse of NavigationMenu).
          roving.with_value(:orientation, :horizontal)
          roving.with_value(:manage_tabindex, true)
          roving.with_value(:loop, loop)
          roving.with_action(:keydown, on: :keydown)
          attrs.to_attributes
        end
      end

      # One logical menu: the trigger + content pair. Radix renders no
      # element here; poetry hosts the pair's poetry--core--menu +
      # poetry--core--popper controllers on a display:contents wrapper
      # (out of the bar's flex layout AND the accessibility tree), keeping
      # the rendered semantics Radix-parity. Plain ViewComponent::Base ON
      # PURPOSE - the nested parts are anatomy, not registry components.
      class Menu < ViewComponent::Base
        include ItemSlots

        attr_reader :value, :disabled

        def initialize(bar:, value: nil, disabled: false, dir: nil, **extra_attributes)
          super()
          @bar = bar
          @disabled = disabled
          @dir = dir
          @extra_attributes = extra_attributes
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
          content_tag(:button, attrs.merge(options)) { capture(&block) }
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
          @instance_id ||= "poetry-menubar-#{SecureRandom.hex(4)}"
        end

        # The per-menu machinery scope: the family menu controller (modal
        # FALSE - the bar's hover-slide needs sibling triggers pressable,
        # so no body scrim / no trap) + its popper with the menubar
        # positioning overrides (align start / alignOffset -4 / sideOffset
        # 8, source-validated).
        def menu_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          menu = Poetry::Core::Stimulus::Builder.new(MENU, attrs)
          menu.register_controller
          menu.with_value(:open, open?)
          menu.with_value(:modal, false)
          popper = Poetry::Core::Stimulus::Builder.new(POPPER, attrs)
          popper.register_controller
          popper.with_value(:side, :bottom)
          popper.with_value(:align, :start)
          popper.with_value(:side_offset, 8)
          popper.with_value(:align_offset, -4)
          popper.with_value(:avoid_collisions, true)
          { "data-slot" => "menubar-menu", "class" => Style.css(:menu) }
            .merge(attrs.to_attributes).merge(@extra_attributes)
        end

        def trigger_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          menubar = Poetry::Core::Stimulus::Builder.new(MENUBAR, attrs)
          menubar.with_action(:toggle, on: :pointerdown)
          menubar.with_action(:hover_slide, on: :pointerenter)
          menubar.with_action(:trigger_keydown, on: :keydown)
          popper = Poetry::Core::Stimulus::Builder.new(POPPER, attrs)
          popper.with_target(:anchor)
          attrs.to_attributes
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
          }.merge(popper_stimulus { |popper| popper.with_target(:content) })
          attrs["hidden"] = true unless open?
          content_tag(:div, attrs) { safe_join(items.map(&:to_s)) }
        end
      end

      # role=group semantic grouping between separators - the same item
      # union, one level down.
      class Group < ViewComponent::Base
        include ItemSlots

        def initialize(dir: nil, **extra_attributes)
          super()
          @dir = dir
          @extra_attributes = extra_attributes
        end

        def before_render
          raise ArgumentError, "Menubar group requires at least one item" unless items?
        end

        def call
          attrs = { "data-slot" => "menubar-group", "role" => "group" }
          content_tag(:div, attrs.merge(@extra_attributes)) { safe_join(items.map(&:to_s)) }
        end

        private

        def menu_dir
          @dir
        end
      end

      # role=group scoping the single-select value for its radio items.
      # Duplicate radio values raise ArgumentError at render (the base-contract
      # base contract); radio items exist ONLY through this group.
      class RadioGroup < ViewComponent::Base
        include Helpers

        attr_reader :group_value

        def initialize(value: nil, **extra_attributes)
          super()
          @group_value = value&.to_s
          @extra_attributes = extra_attributes
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
          content_tag(:div, attrs.merge(options)) do
            safe_join([item_indicator(:circle, Style.css(:indicator_circle)),
                       capture(&block), shortcut_span(shortcut)].compact)
          end
        }

        def before_render
          raise ArgumentError, "Menubar radio group requires at least one with_radio_item" unless radio_items?
        end

        def call
          attrs = { "data-slot" => "menubar-radio-group", "role" => "group" }
          attrs["data-value"] = group_value if group_value
          content_tag(:div, attrs.merge(@extra_attributes)) { safe_join(radio_items.map(&:to_s)) }
        end
      end

      # A submenu scope: its own popper instance (sub_trigger = anchor,
      # sub_content = content; side flips under RTL) around the same item
      # union, recursively - family-identical to DropdownMenu's.
      class Sub < ViewComponent::Base
        include ItemSlots

        def initialize(dir: nil, **extra_attributes)
          super()
          @dir = dir
          @extra_attributes = extra_attributes
        end

        renders_one :trigger, lambda { |inset: false, disabled: false, text_value: nil, **options, &block|
          attrs = {
            "id" => trigger_id, "data-slot" => "menubar-sub-trigger", "role" => "menuitem",
            "tabindex" => "-1", "data-poetry-collection-item" => "",
            "aria-haspopup" => "menu", "aria-expanded" => "false", "aria-controls" => content_id,
            "class" => Style.css(:sub_trigger, class: options.delete(:class))
          }.merge(sub_trigger_stimulus_attributes)
          apply_item_flags(attrs, inset:, disabled:, text_value:)
          content_tag(:div, attrs.merge(options)) do
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
          @instance_id ||= "poetry-menubar-sub-#{SecureRandom.hex(4)}"
        end

        def sub_attributes
          attrs = { "data-slot" => "menubar-sub" }.merge(popper_stimulus do |popper|
            popper.register_controller
            popper.with_value(:side, rtl? ? :left : :right)
            popper.with_value(:align, :start)
          end)
          attrs.merge(@extra_attributes)
        end

        def sub_content
          attrs = {
            "id" => content_id, "role" => "menu", "aria-orientation" => "vertical",
            "aria-labelledby" => trigger_id, "tabindex" => "-1",
            "data-slot" => "menubar-sub-content", "data-closed" => "", "hidden" => true,
            "class" => Style.css(:sub_content)
          }.merge(popper_stimulus { |popper| popper.with_target(:content) })
          content_tag(:div, attrs) { safe_join(items.map(&:to_s)) }
        end

        def sub_trigger_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          menu = Poetry::Core::Stimulus::Builder.new(MENU, attrs)
          menu.with_action(:sub_enter, on: :pointerenter)
          menu.with_action(:sub_leave, on: :pointerleave)
          menu.with_action(:open_sub, on: :click)
          popper = Poetry::Core::Stimulus::Builder.new(POPPER, attrs)
          popper.with_target(:anchor)
          attrs.to_attributes
        end

        def chevron
          render(Icon::Component.new(name: :"chevron-right", class: Style.css(:sub_indicator)))
        end
      end
    end
  end
end
