# frozen_string_literal: true

module Poetry
  module Ui
    # Gives a menu family (DropdownMenu, ContextMenu, Menubar) one shared
    # implementation of the menu item union and its anatomy classes.
    # Family identity - the data-slot prefix, the Style dictionary, the
    # error noun, the builder classes - resolves through the including
    # family's namespace at render time, never through constants named
    # here, so one implementation serves every family. Each family keeps
    # a thin ItemSlots module carrying its own SLOT_BUILDERS and, where
    # needed, a per-kind indicator override.
    module Menus
      # The closed vocabulary for the item variant axis.
      ITEM_VARIANTS = %i[default destructive].freeze

      # Shared attribute builders for the item union - mixed into every
      # menu level (the family roots and the nested Sub / Group /
      # RadioGroup parts) so the whole family renders the same anatomy
      # through the same Builder.
      module Helpers
        include FamilyIdentity

        private

        # menu items are role=menuitem DIVs (APG-exact) - no native
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

        # Every menu item's activation, via the public escape hatch (each
        # family Component's :item declaration mirrors it; the contract
        # gate keeps the two in sync).
        def item_action_attributes
          stimulus_attributes(:menu) { |menu| menu.with_action(:activate, on: :click) }
        end

        # The named check/circle glyph wrapper (the source's two slots:
        # <family>-checkbox-item-indicator / <family>-radio-item-indicator).
        # State is carried by
        # the parent item's aria-checked/data-checked pair; the glyph
        # itself stays decorative (Icon defaults to aria-hidden).
        def item_indicator(icon, icon_class, kind)
          extra = [family_style.css(:item_indicator_state), indicator_extra_class(kind)].compact
          content_tag(:span, "data-slot" => "#{family_slot_prefix}-#{kind}-item-indicator",
                             "class" => family_style.css(:item_indicator, class: extra)) do
            render(Icon::Component.new(name: icon, class: icon_class))
          end
        end

        # The one substantive family fork: Menubar themes its checkbox and
        # radio indicators separately (a per-kind cn class rides along);
        # the siblings share one treatment.
        def indicator_extra_class(_kind)
          nil
        end

        # A VISUAL keybinding hint only - poetry does not bind the key
        # (family rule), so the span is aria-hidden presentation.
        def shortcut_span(text)
          return if text.blank?

          content_tag(:span, text, "data-slot" => "#{family_slot_prefix}-shortcut", "aria-hidden" => "true",
                                   "class" => family_style.css(:shortcut))
        end
      end

      # The item UNION every menu level accepts: item | checkbox_item |
      # radio_group | label | separator | group | sub - one ordered
      # collection (interleaving preserved), polymorphic setters named per
      # part. Included (through each family's thin ItemSlots) by the family
      # roots, Sub (recursive submenus), and Group.
      module ItemSlots
        extend ActiveSupport::Concern
        include Helpers

        included do
          renders_many :items,
                       doc: "The menu composition API: one ordered items collection accepting seven kinds, " \
                            "interleaved in call order - with_item an action row (href: renders it as a real link; " \
                            "submit: as a real submit button) with_checkbox_item a toggleable checked/unchecked row " \
                            "with_radio_group a single-select scope; add rows inside it via with_radio_item(value:) " \
                            "with_label a non-interactive heading for a run of items with_separator a horizontal " \
                            "rule between runs with_group semantic grouping around the same union, one level down " \
                            "with_sub a nested submenu: its own with_trigger plus the same union, recursively",
                       types: {
                         item: { renders: ->(**options, &block) { item_part(**options, &block) }, as: :item },
                         checkbox_item: {
                           renders: ->(**options, &block) { checkbox_item_part(**options, &block) }, as: :checkbox_item
                         },
                         radio_group: { renders: lambda { |**options|
                           family_namespace::RadioGroup.new(**options)
                         }, as: :radio_group },
                         label: { renders: ->(**options, &block) { label_part(**options, &block) }, as: :label },
                         separator: { renders: ->(**options) { separator_part(**options) }, as: :separator },
                         group: { renders: lambda { |**options|
                           family_namespace::Group.new(dir: menu_dir, **options)
                         }, as: :group },
                         sub: { renders: lambda { |**options|
                           family_namespace::Sub.new(dir: menu_dir, **options)
                         }, as: :sub }
                       }
        end

        private

        # Builds one action row - a role=menuitem div, or a real <a> /
        # submit <button> when href: / submit: is given.
        def item_part(**options, &)
          variant = (options.delete(:variant) || :default).to_sym
          unless ITEM_VARIANTS.include?(variant)
            raise ArgumentError,
                  "unknown #{family_name} item variant #{variant.inspect} - known: #{ITEM_VARIANTS.join(", ")}"
          end

          shortcut = options.delete(:shortcut)
          # A link/submit item IS the interactive element (role=menuitem on the
          # <a> or the <button>), never nested inside a menuitem div - one
          # interactive element, so it keeps the APG contract without tripping
          # nested-interactive a11y. A disabled link/submit drops its target and
          # renders as the plain div (anchors/submit-buttons have no menu meaning
          # once inert).
          href = options.delete(:href)
          external = options.delete(:external)
          submit = options.delete(:submit)
          method = options.delete(:method)
          disabled = options[:disabled]
          attrs = {
            "data-slot" => "#{family_slot_prefix}-item", "role" => "menuitem", "tabindex" => "-1",
            "data-poetry-collection-item" => "", "data-variant" => variant,
            "class" => family_style.css(:item, class: options.delete(:class))
          }.merge(item_action_attributes)
          apply_item_flags(attrs, **options.extract!(:inset, :disabled, :text_value, :close_on_select))
          content = safe_join([capture(&), shortcut_span(shortcut)].compact)

          if submit && !disabled
            # form: is RESERVED on submit items - the display:contents form
            # IS the a11y mechanism (the button is the menuitem).
            options.delete(:form)
            options.delete("form")
            # button_to's form is display:contents (transparent); the submit
            # button IS the menuitem, POSTing with CSRF + the method override -
            # the a11y-clean way to run a DELETE/POST action from a menu. The
            # block form renders a <button> (the string form renders an <input>).
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

        # Builds one role=menuitemcheckbox toggle row.
        def checkbox_item_part(**options, &block)
          checked = options.delete(:checked) || false
          shortcut = options.delete(:shortcut)
          attrs = {
            "data-slot" => "#{family_slot_prefix}-checkbox-item", "role" => "menuitemcheckbox", "tabindex" => "-1",
            "data-poetry-collection-item" => "",
            # aria-checked and the data-checked/data-unchecked pair written
            # TOGETHER, never separately.
            "aria-checked" => checked.to_s, (checked ? "data-checked" : "data-unchecked") => "",
            "class" => family_style.css(:checkbox_item, class: options.delete(:class))
          }.merge(item_action_attributes)
          apply_item_flags(attrs, **options.extract!(:disabled, :text_value, :close_on_select))
          content_tag(:div, Poetry::Core::HTML::Attributes.merged(attrs, options)) do
            safe_join([item_indicator(:check, family_style.css(:indicator_check), :checkbox),
                       capture(&block), shortcut_span(shortcut)].compact)
          end
        end

        # Builds the non-interactive heading row.
        def label_part(inset: false, **options, &block)
          attrs = {
            "data-slot" => "#{family_slot_prefix}-label",
            "class" => family_style.css(:label, class: options.delete(:class))
          }
          attrs["data-inset"] = "true" if inset
          content_tag(:div, Poetry::Core::HTML::Attributes.merged(attrs, options)) { capture(&block) }
        end

        # Builds the role=separator rule.
        def separator_part(**options)
          attrs = {
            "data-slot" => "#{family_slot_prefix}-separator", "role" => "separator",
            "aria-orientation" => "horizontal",
            "class" => family_style.css(:separator, class: options.delete(:class))
          }
          content_tag(:div, nil, Poetry::Core::HTML::Attributes.merged(attrs, options))
        end
      end

      # role=group semantic grouping between separators - the same item
      # union, one level down.
      #
      # @api private
      class Group < Poetry::Core::Component
        internal_component!
        include ItemSlots

        def initialize(dir: nil, **extra_attributes)
          super(extra_attributes)
          @dir = dir
        end

        def before_render
          raise ArgumentError, "#{family_name} group requires at least one item" unless items?
        end

        def call
          attrs = { "data-slot" => "#{family_slot_prefix}-group", "role" => "group" }
          content_tag(:div, Poetry::Core::HTML::Attributes.merged(attrs, html_attributes)) { safe_join(items.map(&:to_s)) }
        end

        private

        def menu_dir
          @dir
        end
      end

      # role=group scoping the single-select value for its radio items -
      # radio items exist only through this group; duplicate values raise.
      #
      # @api private
      class RadioGroup < Poetry::Core::Component
        internal_component!
        include Helpers

        attr_reader :group_value

        renders_many :radio_items,
                     doc: "One role=menuitemradio row; value: must be unique within the group.",
                     renders: lambda { |value:, disabled: false, text_value: nil,
                                            close_on_select: nil, shortcut: nil, **options, &block|
                       key = value.to_s
                       unless @seen_values.add?(key)
                         raise ArgumentError, "duplicate #{family_name} radio value #{key.inspect} - values must be " \
                                              "unique within their radio group"
                       end

                       checked = !group_value.nil? && key == group_value
                       attrs = {
                         "data-slot" => "#{family_slot_prefix}-radio-item", "role" => "menuitemradio",
                         "tabindex" => "-1", "data-poetry-collection-item" => "", "data-value" => key,
                         "aria-checked" => checked.to_s, (checked ? "data-checked" : "data-unchecked") => "",
                         "class" => family_style.css(:radio_item, class: options.delete(:class))
                       }.merge(item_action_attributes)
                       apply_item_flags(attrs, disabled:, text_value:, close_on_select:)
                       content_tag(:div, Poetry::Core::HTML::Attributes.merged(attrs, options)) do
                         safe_join([item_indicator(:circle, family_style.css(:indicator_circle), :radio),
                                    capture(&block), shortcut_span(shortcut)].compact)
                       end
                     }

        def initialize(value: nil, **extra_attributes)
          super(extra_attributes)
          @group_value = value&.to_s
          @seen_values = Set.new
        end

        def before_render
          raise ArgumentError, "#{family_name} radio group requires at least one with_radio_item" unless radio_items?
        end

        def call
          attrs = { "data-slot" => "#{family_slot_prefix}-radio-group", "role" => "group" }
          attrs["data-value"] = group_value if group_value
          content_tag(:div, Poetry::Core::HTML::Attributes.merged(attrs, html_attributes)) { safe_join(radio_items.map(&:to_s)) }
        end
      end

      # A submenu scope - its own positioning instance (trigger anchors
      # content; side flips under RTL) around the same item union, recursively.
      #
      # @api private
      class Sub < Poetry::Core::Component
        internal_component!
        include ItemSlots

        renders_one :trigger,
                    doc: "role=menuitem in the PARENT's collection + aria wiring to its own sub-content; the " \
                         "trailing chevron ships built in (flips via logical ml-auto under RTL).",
                    renders: lambda { |inset: false, disabled: false, text_value: nil, **options, &block|
                      attrs = {
                        "id" => trigger_id, "data-slot" => "#{family_slot_prefix}-sub-trigger", "role" => "menuitem",
                        "tabindex" => "-1", "data-poetry-collection-item" => "",
                        "aria-haspopup" => "menu", "aria-expanded" => "false", "aria-controls" => content_id,
                        "class" => family_style.css(:sub_trigger, class: options.delete(:class))
                      }.merge(sub_trigger_stimulus_attributes)
                      apply_item_flags(attrs, inset:, disabled:, text_value:)
                      content_tag(:div, Poetry::Core::HTML::Attributes.merged(attrs, options)) do
                        safe_join([capture(&block), chevron])
                      end
                    }

        def initialize(dir: nil, **extra_attributes)
          super(extra_attributes)
          @dir = dir
        end

        def before_render
          raise ArgumentError, "#{family_name} sub requires with_trigger (the sub-menu item)" unless trigger?
          raise ArgumentError, "#{family_name} sub requires at least one item" unless items?
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
          @instance_id ||= poetry_instance_id("poetry-#{family_slot_prefix}-sub")
        end

        def sub_attributes
          attrs = { "data-slot" => "#{family_slot_prefix}-sub" }.merge(
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
            "data-slot" => "#{family_slot_prefix}-sub-content", "data-closed" => "", "hidden" => true,
            "class" => family_style.css(:sub_content)
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
          render(Icon::Component.new(name: :"chevron-right", class: family_style.css(:sub_indicator)))
        end
      end
    end
  end
end
