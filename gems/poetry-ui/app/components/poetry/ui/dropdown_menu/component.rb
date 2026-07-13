# frozen_string_literal: true

module Poetry
  module Ui
    module DropdownMenu
      # The controller identifiers, declared ONCE - every data attribute
      # derives from them through the Stimulus Builder, validated against
      # the controllers manifest (no hand-written wiring strings).
      MENU = %i[poetry core menu].freeze
      POPPER = %i[poetry core popper].freeze
      ITEM_VARIANTS = %i[default destructive].freeze
      SIDES = %i[top right bottom left].freeze
      ALIGNS = %i[start center end].freeze
      DIRS = %i[ltr rtl].freeze

      # Shared attribute builders for the item union - mixed into the root
      # Component and the nested Sub / Group / RadioGroup parts so every
      # menu level renders the same anatomy through the same Builder.
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
        # disabled, so aria-disabled and data-disabled are written TOGETHER
        # (the controller filters on either; CSS styles data-[disabled]).
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

        # data-slot="dropdown-menu-item-indicator" is a POETRY ADDITION
        # (new-york-v4's span is anonymous) - the self-identification rule.
        # State is carried by the parent item's aria-checked/data-checked pair;
        # the glyph itself stays decorative (Icon defaults to aria-hidden).
        def item_indicator(icon, icon_class)
          content_tag(:span, "data-slot" => "dropdown-menu-item-indicator",
                             "class" => Style.css(:item_indicator, class: Style.css(:item_indicator_state))) do
            render(Icon::Component.new(name: icon, class: icon_class))
          end
        end

        # A VISUAL keybinding hint only - poetry does not bind the key
        # (family rule), so the span is aria-hidden presentation.
        def shortcut_span(text)
          return if text.blank?

          content_tag(:span, text, "data-slot" => "dropdown-menu-shortcut", "aria-hidden" => "true",
                                   "class" => Style.css(:shortcut))
        end
      end

      # The item UNION every menu level accepts: item | checkbox_item |
      # radio_group | label | separator | group | sub - one ordered
      # collection (interleaving preserved), polymorphic setters named per
      # part (with_item, with_checkbox_item, ...). Included by the root
      # Component, Sub (recursive submenus), and Group.
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
                  "unknown DropdownMenu item variant #{variant.inspect} - known: #{ITEM_VARIANTS.join(", ")}"
          end

          shortcut = options.delete(:shortcut)
          attrs = {
            "data-slot" => "dropdown-menu-item", "role" => "menuitem", "tabindex" => "-1",
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
            "data-slot" => "dropdown-menu-checkbox-item", "role" => "menuitemcheckbox", "tabindex" => "-1",
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
            "data-slot" => "dropdown-menu-label",
            "class" => Style.css(:label, class: options.delete(:class))
          }
          attrs["data-inset"] = "true" if inset
          content_tag(:div, attrs.merge(options)) { capture(&block) }
        end

        def separator_part(**options)
          attrs = {
            "data-slot" => "dropdown-menu-separator", "role" => "separator",
            "aria-orientation" => "horizontal",
            "class" => Style.css(:separator, class: options.delete(:class))
          }
          content_tag(:div, nil, attrs.merge(options))
        end
      end

      # The menus-family ANCHOR (DropdownMenu): a
      # button-triggered role=menu popup on the shipped primitive stack.
      # Two hosts, one owned controller: the root carries poetry--core--menu
      # (open/activate/typeahead/submenus) + poetry--core--popper (trigger-
      # anchored positioning); the content's layer controllers (focus-scope,
      # dismissable, roving-focus) are TOKEN-ACTIVATED by the menu
      # controller on open - a statically-connected trap on a hidden menu
      # would steal focus at page load, so the markup renders NO layer
      # tokens (menu_controller.js appends/removes them).
      class Component < Poetry::Core::Component
        include ItemSlots

        AGENT_RULES = [
          "Use poetry_dropdown_menu - never hand-roll role=menu popups with Tailwind.",
          "Items are ACTIONS. Choosing a form VALUE is a Select/Combobox - do not fake it with radio items.",
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
                                    "closed state)"
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

        # The trigger is a poetry Button wired as the menu button (demo
        # parity: with_trigger(variant: :outline) { "Open" }) - the slot
        # owns the aria-haspopup/expanded/controls wiring regardless of
        # the composed content, so composition cannot drop the aria.
        renders_one :trigger, lambda { |**options, &block|
          wiring = {
            "id" => trigger_id, "data-slot" => "dropdown-menu-trigger",
            "aria-haspopup" => "menu", "aria-expanded" => open.to_s, "aria-controls" => content_id
          }.merge(trigger_stimulus_attributes)
          # Base UI trigger state: bare data-popup-open while open, NO
          # attribute while closed (absence IS the state).
          wiring["data-popup-open"] = "" if open
          options[:disabled] = true if disabled && !options.key?(:disabled)
          Button::Component.new(**wiring, **options, &block)
        }

        # The forwarding-lambda component fact: with_trigger renders a
        # Button - callers get Button's full typed-slot contract statically.
        SLOT_RENDERS = { trigger: Button::Component }.freeze

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
            root.merge(root_stimulus_attributes).merge(component_data_attributes)
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
          }.merge(popper_stimulus { |popper| popper.with_target(:content) })
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
          @instance_id ||= "poetry-dropdown-menu-#{SecureRandom.hex(4)}"
        end

        # BOTH controllers build into ONE Attributes instance - a plain
        # Hash#merge of two would overwrite data-controller instead of
        # token-concatenating it (the Accordion lesson).
        def root_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          menu = Poetry::Core::Stimulus::Builder.new(MENU, attrs)
          menu.register_controller
          menu.with_value(:open, open)
          menu.with_value(:modal, modal)
          menu.with_value(:loop, loop)
          popper = Poetry::Core::Stimulus::Builder.new(POPPER, attrs)
          popper.register_controller
          popper.with_value(:side, side)
          popper.with_value(:align, align)
          popper.with_value(:side_offset, side_offset)
          popper.with_value(:align_offset, align_offset)
          popper.with_value(:avoid_collisions, avoid_collisions)
          attrs.to_attributes
        end

        def trigger_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          menu = Poetry::Core::Stimulus::Builder.new(MENU, attrs)
          menu.with_action(:toggle, on: :click)
          menu.with_action(:trigger_keydown, on: :keydown)
          popper = Poetry::Core::Stimulus::Builder.new(POPPER, attrs)
          popper.with_target(:anchor)
          attrs.to_attributes
        end
      end

      # role=group semantic grouping between separators - the same item
      # union, one level down. Plain ViewComponent::Base ON PURPOSE:
      # Poetry::Core::Component descendants register in the component
      # registry, and the nested parts are anatomy, not components.
      class Group < ViewComponent::Base
        include ItemSlots

        def initialize(dir: nil, **extra_attributes)
          super()
          @dir = dir
          @extra_attributes = extra_attributes
        end

        def before_render
          raise ArgumentError, "DropdownMenu group requires at least one item" unless items?
        end

        def call
          attrs = { "data-slot" => "dropdown-menu-group", "role" => "group" }
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
            raise ArgumentError, "duplicate DropdownMenu radio value #{key.inspect} - values must be " \
                                 "unique within their radio group"
          end

          checked = !group_value.nil? && key == group_value
          attrs = {
            "data-slot" => "dropdown-menu-radio-item", "role" => "menuitemradio", "tabindex" => "-1",
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
          raise ArgumentError, "DropdownMenu radio group requires at least one with_radio_item" unless radio_items?
        end

        def call
          attrs = { "data-slot" => "dropdown-menu-radio-group", "role" => "group" }
          attrs["data-value"] = group_value if group_value
          content_tag(:div, attrs.merge(@extra_attributes)) { safe_join(radio_items.map(&:to_s)) }
        end
      end

      # A submenu scope: its own popper instance (sub_trigger = anchor,
      # sub_content = content; side flips under RTL) around the same item
      # union, recursively. The sub layer controllers (dismissable +
      # roving-focus) are added by the menu controller when the sub opens.
      class Sub < ViewComponent::Base
        include ItemSlots

        def initialize(dir: nil, **extra_attributes)
          super()
          @dir = dir
          @extra_attributes = extra_attributes
        end

        # role=menuitem in the PARENT's collection + aria wiring to its own
        # sub-content; the trailing chevron ships built in (flips via
        # logical ml-auto under RTL).
        renders_one :trigger, lambda { |inset: false, disabled: false, text_value: nil, **options, &block|
          attrs = {
            "id" => trigger_id, "data-slot" => "dropdown-menu-sub-trigger", "role" => "menuitem",
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
          raise ArgumentError, "DropdownMenu sub requires with_trigger (the sub-menu item)" unless trigger?
          raise ArgumentError, "DropdownMenu sub requires at least one item" unless items?
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
          @instance_id ||= "poetry-dropdown-menu-sub-#{SecureRandom.hex(4)}"
        end

        def sub_attributes
          attrs = { "data-slot" => "dropdown-menu-sub" }.merge(popper_stimulus do |popper|
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
            "data-slot" => "dropdown-menu-sub-content", "data-closed" => "", "hidden" => true,
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
