# frozen_string_literal: true

module Poetry
  module Ui
    module ContextMenu
      # The controller identifiers, declared ONCE - every data attribute
      # derives from them through the Stimulus Builder, validated against
      # the controllers manifest (no hand-written wiring strings).
      CONTEXT_MENU = %i[poetry core context_menu].freeze
      MENU = %i[poetry core menu].freeze
      POPPER = %i[poetry core popper].freeze
      ITEM_VARIANTS = %i[default destructive].freeze
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

        # data-slot="context-menu-item-indicator" is a POETRY ADDITION
        # (new-york-v4's span is anonymous) - the self-identification rule.
        def item_indicator(icon, icon_class)
          content_tag(:span, "data-slot" => "context-menu-item-indicator",
                             "class" => Style.css(:item_indicator, class: Style.css(:item_indicator_state))) do
            render(Icon::Component.new(name: icon, class: icon_class))
          end
        end

        # A VISUAL keybinding hint only - poetry does not bind the key
        # (family rule), so the span is aria-hidden presentation.
        def shortcut_span(text)
          return if text.blank?

          content_tag(:span, text, "data-slot" => "context-menu-shortcut", "aria-hidden" => "true",
                                   "class" => Style.css(:shortcut))
        end
      end

      # The item UNION every menu level accepts (family-identical to
      # DropdownMenu): item | checkbox_item |
      # radio_group | label | separator | group | sub - one ordered
      # collection, polymorphic setters named per part. Included by the
      # root Component, Sub (recursive submenus), and Group.
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
                  "unknown ContextMenu item variant #{variant.inspect} - known: #{ITEM_VARIANTS.join(", ")}"
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
            "data-slot" => "context-menu-item", "role" => "menuitem", "tabindex" => "-1",
            "data-poetry-collection-item" => "", "data-variant" => variant,
            "class" => Style.css(:item, class: options.delete(:class))
          }.merge(item_action_attributes)
          apply_item_flags(attrs, **options.extract!(:inset, :disabled, :text_value, :close_on_select))
          content = safe_join([capture(&block), shortcut_span(shortcut)].compact)

          if submit && !disabled
            return helpers.button_to(submit,
                                     { method: method || :post, form: { class: "contents" } }
                                       .merge(attrs).merge(options)) { content }
          end

          link = href && !disabled
          if link
            attrs["href"] = href
            attrs.merge!("target" => "_blank", "rel" => "noopener noreferrer") if external
          end
          content_tag(link ? :a : :div, attrs.merge(options)) { content }
        end

        def checkbox_item_part(**options, &block)
          checked = options.delete(:checked) || false
          shortcut = options.delete(:shortcut)
          attrs = {
            "data-slot" => "context-menu-checkbox-item", "role" => "menuitemcheckbox", "tabindex" => "-1",
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
            "data-slot" => "context-menu-label",
            "class" => Style.css(:label, class: options.delete(:class))
          }
          attrs["data-inset"] = "true" if inset
          content_tag(:div, attrs.merge(options)) { capture(&block) }
        end

        def separator_part(**options)
          attrs = {
            "data-slot" => "context-menu-separator", "role" => "separator",
            "aria-orientation" => "horizontal",
            "class" => Style.css(:separator, class: options.delete(:class))
          }
          content_tag(:div, nil, attrs.merge(options))
        end
      end

      # The menus-family sibling (ContextMenu): the same
      # shared machinery as DropdownMenu, with the trigger DELTA - a
      # right-click/long-press SURFACE, not a button. The surface is NOT a
      # widget: no role, no aria-haspopup, not in the tab order (unless
      # focusable_surface: opts in); with no JS the browser-native context
      # menu appears untouched (the suite's strongest PE story). Position
      # is FORCED (side right / align start / offset 2, Radix parity) -
      # context menus anchor at the pointer via popper's virtual-anchor
      # mode, written by the thin poetry--core--context-menu controller.
      class Component < Poetry::Core::Component
        include ItemSlots

        AGENT_RULES = [
          "NEVER make a context menu the only path to an action - it is an invisible affordance; every " \
          "item needs a visible equivalent (a '...' DropdownMenu button, a toolbar, a detail page).",
          "Choose ContextMenu only for right-click-on-an-object semantics; a visible button opening a " \
          "menu is DropdownMenu.",
          "Do not add aria-haspopup or a role to the trigger surface; do not make it focusable except " \
          "via focusable_surface: true.",
          "Do not try to set side/align/side_offset - context menus anchor at the pointer, always.",
          "Wrap the whole logical object (row/card) as the trigger surface, not a fragment.",
          "Destructive items use variant: :destructive AND still confirm irreversible actions via a dialog.",
          "shortcut: is a visual hint only - it does NOT bind the key.",
          "Do not nest a ContextMenu trigger surface inside another ContextMenu trigger surface."
        ].freeze

        option :open, :boolean, default: false
        option :modal, :boolean, default: true
        option :long_press_delay, :integer, default: 700
        option :disabled, :boolean, default: false
        option :label, :string
        option :focusable_surface, :boolean, default: false
        option :dir, :symbol

        validates :dir, inclusion: { in: DIRS }, allow_nil: true

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
               "data-side" => { condition: "the placement side (forced right initially; popper re-writes " \
                                           "it after collision flips)",
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

        # DELTA - the right-click/long-press SURFACE: wraps arbitrary
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
          }.merge(trigger_stimulus_attributes)
          # Base UI trigger state: bare data-popup-open while open, NO
          # attribute while closed (absence IS the state).
          attrs["data-popup-open"] = "" if open
          attrs["data-disabled"] = "" if disabled
          if focusable_surface
            attrs["tabindex"] = "0"
            attrs["aria-keyshortcuts"] = "Shift+F10"
          end
          content_tag(tag_name, attrs.merge(options)) { capture(&block) }
        }

        def before_render
          raise ArgumentError, "ContextMenu requires with_trigger (the right-click surface)" unless trigger?
          raise ArgumentError, "ContextMenu requires at least one item" unless items?
        end

        def trigger_id
          "#{instance_id}-trigger"
        end

        def content_id
          "#{instance_id}-content"
        end

        def root_attributes
          root = { "data-slot" => "context-menu" }
          root["dir"] = dir.to_s if dir
          html_attributes.merge_if_not_set(
            root.merge(root_stimulus_attributes).merge(component_data_attributes)
          )
        end

        def content_attributes
          attrs = {
            "id" => content_id, "role" => "menu", "aria-orientation" => "vertical",
            # No aria-labelledby to the trigger (it is not a widget - the
            # delta): the menu's name is label: -> the i18n fallback.
            "aria-label" => label.presence || t("poetry.context_menu.menu_label_fallback"),
            "tabindex" => "-1",
            "data-slot" => "context-menu-content", (open ? "data-open" : "data-closed") => "",
            # The FORCED initial placement (re-resolved live by popper).
            "data-side" => "right", "data-align" => "start",
            "class" => css(:content)
          }.merge(popper_stimulus { |popper| popper.with_target(:content) })
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
          @instance_id ||= "poetry-context-menu-#{SecureRandom.hex(4)}"
        end

        # THREE controllers build into ONE Attributes instance - a plain
        # Hash#merge would overwrite data-controller instead of
        # token-concatenating it (the Accordion lesson).
        def root_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          context = Poetry::Core::Stimulus::Builder.new(CONTEXT_MENU, attrs)
          context.register_controller
          context.with_value(:long_press_delay, long_press_delay)
          context.with_value(:disabled, disabled)
          menu = Poetry::Core::Stimulus::Builder.new(MENU, attrs)
          menu.register_controller
          menu.with_value(:open, open)
          menu.with_value(:modal, modal)
          popper = Poetry::Core::Stimulus::Builder.new(POPPER, attrs)
          popper.register_controller
          # side right / side_offset 2 / align start FORCED, not API (Radix
          # omits these props on ContextMenu.Content); collisions still flip.
          popper.with_value(:side, :right)
          popper.with_value(:align, :start)
          popper.with_value(:side_offset, 2)
          popper.with_value(:avoid_collisions, true)
          attrs.to_attributes
        end

        # The surface's wiring: contextmenu + the long-press pointer set ->
        # the delta controller; popper's anchor target is the FALLBACK rect
        # for positionless/keyboard opens (the virtual anchor point wins
        # whenever one is stored).
        def trigger_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          context = Poetry::Core::Stimulus::Builder.new(CONTEXT_MENU, attrs)
          context.with_action(:open, on: :contextmenu)
          context.with_action(:press_start, on: :pointerdown)
          context.with_action(:press_cancel, on: %i[pointermove pointerup pointercancel])
          popper = Poetry::Core::Stimulus::Builder.new(POPPER, attrs)
          popper.with_target(:anchor)
          attrs.to_attributes
        end
      end

      # role=group semantic grouping between separators - the same item
      # union, one level down. Plain ViewComponent::Base ON PURPOSE (the
      # nested parts are anatomy, not registry components).
      class Group < ViewComponent::Base
        include ItemSlots

        def initialize(dir: nil, **extra_attributes)
          super()
          @dir = dir
          @extra_attributes = extra_attributes
        end

        def before_render
          raise ArgumentError, "ContextMenu group requires at least one item" unless items?
        end

        def call
          attrs = { "data-slot" => "context-menu-group", "role" => "group" }
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
            raise ArgumentError, "duplicate ContextMenu radio value #{key.inspect} - values must be " \
                                 "unique within their radio group"
          end

          checked = !group_value.nil? && key == group_value
          attrs = {
            "data-slot" => "context-menu-radio-item", "role" => "menuitemradio", "tabindex" => "-1",
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
          raise ArgumentError, "ContextMenu radio group requires at least one with_radio_item" unless radio_items?
        end

        def call
          attrs = { "data-slot" => "context-menu-radio-group", "role" => "group" }
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
            "id" => trigger_id, "data-slot" => "context-menu-sub-trigger", "role" => "menuitem",
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
          raise ArgumentError, "ContextMenu sub requires with_trigger (the sub-menu item)" unless trigger?
          raise ArgumentError, "ContextMenu sub requires at least one item" unless items?
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
          @instance_id ||= "poetry-context-menu-sub-#{SecureRandom.hex(4)}"
        end

        def sub_attributes
          attrs = { "data-slot" => "context-menu-sub" }.merge(popper_stimulus do |popper|
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
            "data-slot" => "context-menu-sub-content", "data-closed" => "", "hidden" => true,
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
        REQUIRED_SLOTS = { trigger: "the right-click surface", item: "at least one item" }.freeze
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
