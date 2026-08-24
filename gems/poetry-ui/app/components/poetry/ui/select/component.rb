# frozen_string_literal: true

module Poetry
  module Ui
    # A single-select dropdown field: a combobox trigger opening a popup listbox.
    module Select
      # The closed vocabulary for the trigger size axis.
      SIZES = %i[sm default].freeze
      # The closed vocabulary for the popup placement-side axis.
      SIDES = %i[top right bottom left].freeze
      # The closed vocabulary for the popup alignment axis.
      ALIGNS = %i[start center end].freeze
      # The closed vocabulary for the text-direction axis.
      DIRS = %i[ltr rtl].freeze

      # The server-side option registry: every rendered option (DOM order)
      # lands here so the hidden native <select> and the trigger's value
      # display are rendered from the same truth as the listbox items.
      # Duplicate values raise at render.
      #
      # @api private
      class OptionSet
        # One registered option: committable value, plain-text label, disabled flag.
        Entry = Struct.new(:value, :label, :disabled)

        attr_reader :entries

        def initialize
          @entries = []
          @seen = Set.new
        end

        def add(value:, label:, disabled: false)
          key = value.to_s
          raise ArgumentError, "Select item requires a non-blank value:" if key.blank?
          unless @seen.add?(key)
            raise ArgumentError, "duplicate Select option value #{key.inspect} - option values must be " \
                                 "unique within their select"
          end

          @entries << Entry.new(key, label, disabled)
        end

        def label_for(value)
          entries.find { |entry| entry.value == value }&.label
        end
      end

      # Shared part builders for the option union - mixed into the root
      # Component and the nested Group so both levels render the same
      # anatomy. Hosts must expose #option_set (the shared OptionSet) and
      # #selected_value.
      #
      # @api private
      module Helpers
        private

        # Hosts must expose #item_wiring (the root Component computes it
        # from its :item declaration; Group receives it at construction).
        def item_component(**)
          Item.new(option_set: option_set, selected_value: selected_value,
                   item_wiring: item_wiring, **)
        end

        def separator_part(**options)
          attrs = {
            "data-slot" => "select-separator", "aria-hidden" => "true",
            "class" => Style.css(:separator, class: options.delete(:class))
          }
          content_tag(:div, nil, attrs.merge(options))
        end

        # Server-rendered always - the parent item's data-selected absence
        # hides the check, so it stays decorative.
        def item_indicator
          content_tag(:span, "data-slot" => "select-item-indicator",
                             "class" => Style.css(:item_indicator, class: Style.css(:item_indicator_state))) do
            render(Icon::Component.new(name: :check, class: Style.css(:indicator_check)))
          end
        end
      end

      # One role=option div. A part component on purpose (not an eager
      # lambda): rendering happens in DOM order inside the viewport, so the
      # shared OptionSet registers options in exactly the order the native
      # <select> must mirror - whether the item sits at the top level or
      # inside a group. aria-selected and data-selected are written
      # together, never separately (unselected = data-selected absent);
      # disabled divs carry aria-disabled + data-disabled together.
      #
      # @api private
      class Item < Poetry::Core::Component
        internal_component!
        include Helpers

        attr_reader :option_set, :selected_value

        def initialize(option_set:, selected_value:, value:, item_wiring: {}, **options)
          super(options)
          @item_wiring = item_wiring
          @option_set = option_set
          @selected_value = selected_value
          @value = value.to_s
          @disabled = options.delete(:disabled) || false
          @text_value = options.delete(:text_value)
        end

        def call
          label_html = content || "".html_safe
          plain_label = (@text_value.presence || ActionView::Base.full_sanitizer.sanitize(label_html.to_s)).squish
          option_set.add(value: @value, label: plain_label, disabled: @disabled)

          selected = selected_value.present? && @value == selected_value
          attrs = {
            "data-slot" => "select-item", "role" => "option", "tabindex" => "-1",
            "data-poetry-collection-item" => "", "data-value" => @value,
            "aria-selected" => selected.to_s,
            "class" => Style.css(:item, class: html_attributes.delete(:class))
          }.merge(@item_wiring)
          # Selected state: bare data-selected on the committed option,
          # nothing while unselected (absence IS the state).
          attrs["data-selected"] = "" if selected
          if @disabled
            attrs["aria-disabled"] = "true"
            attrs["data-disabled"] = ""
          end
          attrs["data-text-value"] = @text_value if @text_value
          merged = Poetry::Core::HTML::Attributes.merged(attrs, html_attributes)
          # data-value is RESERVED (the native-<select> mirror matches
          # options by it) - the value: argument beats any caller spelling.
          merged["data-value"] = @value
          content_tag(:div, merged) do
            safe_join([item_indicator,
                       content_tag(:span, label_html, "data-slot" => "select-item-text",
                                                      "class" => "cn-select-item-text shrink-0 whitespace-nowrap")])
          end
        end
      end

      # A single-select dropdown: a button showing the committed value that
      # opens a popup listbox of options, with arrow-key navigation and
      # typeahead. Reach for it when a form field commits exactly one value
      # from a short, known list (long or filterable lists belong to
      # Combobox; 2-4 options read better as a RadioGroup).
      #
      # Form participation: a visually-hidden native <select> with real
      # server-rendered <option>s is the serialization truth - the initial
      # value posts before any JS runs, required: rides native constraint
      # validation, browser autofill lands on the native select and is
      # adopted into the UI, and committing an option dispatches native
      # change/input events so auto-submitting forms work unmodified. The
      # popup drops below the trigger by default. Every Select needs an
      # accessible name (a Field label via id:, or aria-label) or it
      # raises at render.
      #
      # @example A named form select
      #   render Poetry::Ui::Select::Component.new(name: "fruit", id: "fruit",
      #                                            placeholder: "Pick a fruit") do |select|
      #     select.with_item(value: "apple") { "Apple" }
      #     select.with_item(value: "banana") { "Banana" }
      #   end
      class Component < Poetry::Core::Component
        include Helpers

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Use poetry_select (f.poetry_select in forms) - never hand-roll role=listbox popups, and never " \
          "fake a select with DropdownMenu radio items bound to a hidden field.",
          "Options are VALUES. If activating an option should DO something beyond setting a value, it's a " \
          "DropdownMenu item.",
          "In forms, ALWAYS go through f.poetry_select - it wires name/id/value/errors/required; bare " \
          "poetry_select in a form is a smell.",
          "Every Select MUST be named: a Field label (id: + label[for]) or aria-label. A bare unnamed " \
          "select fails at render - do not suppress it.",
          "NEVER write aria-selected without its data-selected twin, and NEVER write the display text without " \
          "writing the native select's value first - the controller does all three; agents patching DOM must too.",
          "Do not put interactive elements inside options (an option IS the interactive unit).",
          "Long/filterable/async lists or multi-select -> Combobox, not a 50-option Select; 2-4 options -> " \
          "RadioGroup.",
          "The hidden native select is plumbing - never target it with styles, labels, or Capybara " \
          "selectors (drive the combobox like a user).",
          "Positioning is popper-only: poetry Select drops below the trigger (the item-aligned overlay " \
          "mode is not ported - a documented parity delta)."
        ].freeze

        # The trigger-bound ARIA surface: Field's control_attributes (and
        # bare aria-label usage) land on the TRIGGER - the combobox is the
        # interactive control the label must reach - never on the root div.
        TRIGGER_ARIA_KEYS = %w[label labelledby describedby invalid required].freeze

        # The same facts the before_render raise enforces, stated statically
        # so static checks can flag a missing item without rendering.
        REQUIRED_SLOTS = { item: "at least one item" }.freeze

        slot_doc :trigger, "Optional custom trigger content rendered BEFORE the value span (rare); the component " \
                           "owns role=combobox + the aria wiring + the chevron regardless, so composition cannot " \
                           "drop the contract."
        renders_one :trigger

        slot_doc :items, "The option UNION: item | group (label + items) | separator - one ordered collection " \
                         "(interleaving preserved; items and groups are part COMPONENTS so option registration " \
                         "follows render/DOM order). Scroll buttons, the viewport, and the native select are " \
                         "component-owned anatomy, never caller-placed."
        renders_many :items, types: {
          item: { renders: ->(**options) { item_component(**options) }, as: :item },
          group: {
            renders: lambda { |**options|
              Group.new(option_set: option_set, selected_value: selected_value,
                        item_wiring: item_wiring, **options)
            },
            as: :group
          },
          separator: { renders: ->(**options) { separator_part(**options) }, as: :separator }
        }

        use_stimulus do
          on :root do
            controller :select do
              register
              value :open
              value :value, from: :value_string
              value :modal
              value :loop
              value :align_item_with_trigger
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
            controller :select do
              action :toggle, on: :click
              action :trigger_keydown, on: :keydown
            end
            controller(:popper) { target :anchor }
          end
          on :content do
            controller(:popper) { target :content }
          end
          # Every option row (root-level and grouped) - the anatomy
          # classes receive it as item_wiring at construction.
          on :item do
            controller(:select) { action :commit, on: :click }
          end
          on :native do
            controller(:select) { action :native_changed, on: :change }
          end
          on :viewport do
            controller(:select) { action :sync_scroll_buttons, on: :scroll }
          end
          on :scroll_button do
            controller :select do
              action :scroll_hold_start, on: :pointerenter
              action :scroll_hold_stop, on: :pointerleave
            end
          end
        end

        option :value, :string,
               doc: "The committed option value - the item whose value: matches renders as selected and its label " \
                    "fills the trigger."
        option :name, :string, doc: "The form field name, carried by the hidden native <select>."
        option :placeholder, :string,
               doc: "Text shown in the trigger until an option is committed; also rendered as the blank native " \
                    "<option> (posts \"\" when untouched)."
        option :id, :string,
               doc: "The trigger's DOM id - what a Field label's for: must point at; giving one also satisfies the " \
                    "accessible-name requirement."
        option :open, :boolean, default: false, doc: "Server-renders the popup already open."
        option :required, :boolean, default: false,
                                    doc: "Marks the hidden native <select> required - native constraint validation " \
                                         "blocks submission while unset."
        option :disabled, :boolean, default: false, doc: "Disables the trigger and the hidden native <select>."
        option :modal, :boolean, default: true, doc: "While open, blocks pointer interaction outside the popup."
        option :side, :symbol, default: :bottom, doc: "Preferred popup side relative to the trigger."
        option :align, :symbol, default: :start, doc: "Popup alignment along the chosen side's edge."
        option :side_offset, :integer, default: 4, doc: "Gap in pixels between trigger and popup."
        option :align_offset, :integer, default: 0, doc: "Pixel shift along the alignment axis."
        option :avoid_collisions, :boolean, default: true, doc: "Flips/shifts the popup to keep it inside the viewport."
        option :loop, :boolean, default: false,
                                doc: "Arrow-key navigation wraps from the last option back to the first."
        option :align_item_with_trigger, :boolean, default: false,
                                                   doc: "Opens the popup OVER the trigger with the selected item " \
                                                        "aligned on it (native-select feel); falls back to regular " \
                                                        "below-the-trigger positioning on touch, viewport-edge " \
                                                        "triggers, or squeezed heights."
        option :dir, :symbol, doc: "Text direction for the select and its popup."
        option :size, :symbol, default: :default, doc: "The trigger size axis."
        option :trigger_class, :string,
               doc: "Extra classes merged onto the trigger button (e.g. w-full over the base w-fit); class: styles " \
                    "the root wrapper instead."

        validates :size, inclusion: { in: SIZES }
        validates :side, inclusion: { in: SIDES }
        validates :align, inclusion: { in: ALIGNS }
        validates :dir, inclusion: { in: DIRS }, allow_nil: true

        part "select", "Root wrapper carrying both controllers (select + popper) and the " \
                       "optional dir attribute"
        part "select-native", "The visually-hidden native <select> - the serialization truth " \
                              "(name/required/disabled + every option); plumbing, never styled or targeted"
        part "select-trigger", "The role=combobox button the field label reaches - the value " \
                               "display and chevron ride inside",
             states: {
               "data-size" => { condition: "always - the resolved size variant",
                                values: SIZES.map(&:to_s) },
               "data-placeholder" => "no option is committed (bare; the controller toggles it " \
                                     "on every commit)",
               "data-popup-open" => "the popup is open (bare while open, absent while closed - " \
                                    "the controller flips it with the open state)"
             }
        part "select-value", "The value display span - the selected option's label, or the placeholder",
             states: {
               "data-placeholder" => "placeholder: is given - carries the placeholder text so a " \
                                     "later clear can restore it"
             }
        part "select-content", "The popper-positioned popup shell (scroll buttons + viewport) - " \
                               "open/closed and the resolved placement ride here",
             states: {
               "data-open" => "popup is open (the controller flips the pair at runtime)",
               "data-closed" => "popup is closed or animating out (the server-rendered state)",
               "data-side" => { condition: "the placement side - server-rendered from side:, " \
                                           "rewritten to the resolved side by popper on open",
                                values: SIDES.map(&:to_s) },
               "data-align" => { condition: "the placement alignment - server-rendered from " \
                                            "align:, rewritten by popper on open",
                                 values: ALIGNS.map(&:to_s) }
             },
             vars: {
               "--transform-origin" => "popper - the animation origin matching the resolved placement",
               "--available-width" => "popper - viewport space available to the popup post-flip",
               "--available-height" => "popper - viewport space available to the popup post-flip",
               "--anchor-width" => "popper - the trigger's measured width",
               "--anchor-height" => "popper - the trigger's measured height",
               "--radix-select-trigger-width" => "the select controller measures the trigger on " \
                                                 "open - the viewport's min-width binding",
               "--radix-select-trigger-height" => "the select controller measures the trigger on " \
                                                  "open - the viewport's MINIMUM-height binding " \
                                                  "(a hard height collapses the popup to the " \
                                                  "trigger; the list grows past it)"
             }
        part "select-scroll-up-button", "Hover-scroll affordance above the viewport - rendered " \
                                        "always but hidden; the controller unhides it per scroll " \
                                        "extremes (aria-hidden)"
        part "select-scroll-down-button", "Hover-scroll affordance below the viewport (the same " \
                                          "contract as the up button)"
        part "select-viewport", "The role=listbox scroll container - the options' actual parent, " \
                                "labelled from the trigger"
        part "select-group", "role=group wrapper labelled by its select-label heading"
        part "select-label", "The group heading - styled, no ARIA role (the group points at it " \
                             "via aria-labelledby)"
        part "select-item", "One role=option div - selection, disablement, and the committable " \
                            "value ride here",
             states: {
               "data-value" => "always - the option's committable value (the native <option> twin)",
               "data-selected" => "the option is committed (bare; absent while unselected - the " \
                                  "controller twin-writes it with aria-selected)",
               "data-disabled" => "disabled: is set (aria-disabled rides along)"
             }
        part "select-item-indicator", "The check gutter - server-rendered always; the parent " \
                                      "item's data-selected absence hides it"
        part "select-item-text", "The option's label span - the value display copies from it"
        part "select-separator", "Decorative divider between options (aria-hidden)"

        # @api private
        def initialize(attributes = {})
          if attributes.key?(:multiple) || attributes.key?("multiple")
            raise ArgumentError, "Select does not support multiple: - multi-select is Combobox territory"
          end

          super
          @trigger_aria = extract_trigger_aria!
        end

        # @api private
        def before_render
          raise ArgumentError, "Select requires at least one item (with_item / with_group)" unless items?

          return if named?

          raise ArgumentError, "Select requires an accessible name - compose with a Field label " \
                               "(id: + label[for: id]) or pass 'aria-label'"
        end

        # The Field-targetable id lands on the TRIGGER (label[for=id]
        # click-focuses the combobox); content/native ids derive from it.
        # @api private
        def trigger_id
          @trigger_id ||= id.presence || poetry_instance_id("poetry-select")
        end

        # @api private
        def content_id
          "#{trigger_id}-content"
        end

        # @api private
        def native_id
          "#{trigger_id}-native"
        end

        # @api private
        def option_set
          @option_set ||= OptionSet.new
        end

        # @api private
        def selected_value
          @selected_value ||= value.presence.to_s
        end

        # @api private
        def selected_label
          option_set.label_for(selected_value) if selected_value.present?
        end

        # @api private
        def root_attributes
          root = { "data-slot" => "select" }
          root["dir"] = dir.to_s if dir
          html_attributes.merge_if_not_set(
            root.merge(stimulus_attributes_for(:root)).merge(component_data_attributes)
          )
        end

        # The serialization truth: a real <select> carrying name/required/
        # disabled and ALL options with selected - visually hidden (sr-only,
        # painted) and out of both trees (aria-hidden + tabindex=-1). Its
        # change event is the autofill-adoption path.
        # @api private
        def native_select
          attrs = {
            "id" => native_id, "data-slot" => "select-native",
            "aria-hidden" => "true", "tabindex" => "-1", "class" => Style.css(:native)
          }
          attrs["name"] = name if name.present?
          attrs["required"] = true if required
          attrs["disabled"] = true if disabled
          attrs.merge!(stimulus_attributes_for(:native))
          content_tag(:select, native_options, attrs)
        end

        # @api private
        def trigger_button
          attrs = {
            "id" => trigger_id, "data-slot" => "select-trigger", "type" => "button",
            "role" => "combobox", "aria-expanded" => open.to_s, "aria-controls" => content_id,
            "aria-autocomplete" => "none", "data-size" => size.to_s,
            "class" => css(:trigger, class: trigger_class)
          }
          # Trigger open state: bare data-popup-open while open, no
          # attribute while closed (absence IS the state).
          attrs["data-popup-open"] = "" if open
          attrs["data-placeholder"] = "" unless selected_label
          attrs["disabled"] = true if disabled
          attrs.merge!(stimulus_attributes_for(:trigger))
          attrs.merge!(trigger_aria_attributes)
          content_tag(:button, attrs) do
            safe_join([trigger, value_display, chevron].compact)
          end
        end

        # @api private
        def content_attributes
          # No widget role here: the popup shell holds scroll buttons too,
          # and role=listbox permits only option/group children (axe
          # aria-required-children) - the role lives on the
          # viewport, the options' actual parent.
          attrs = {
            "id" => content_id,
            "tabindex" => "-1", "data-slot" => "select-content", (open ? "data-open" : "data-closed") => "",
            # Initial placement, re-resolved live by popper on open.
            "data-side" => side, "data-align" => align,
            "class" => css(:content)
          }.merge(stimulus_attributes_for(:content))
          attrs["hidden"] = true unless open
          attrs
        end

        # @api private
        def viewport_attributes
          {
            "data-slot" => "select-viewport", "role" => "listbox",
            "aria-labelledby" => @trigger_aria["labelledby"].presence || trigger_id,
            "class" => css(:viewport)
          }.merge(stimulus_attributes_for(:viewport))
        end

        # Scroll affordances render ALWAYS but hidden - the controller owns
        # visibility per scroll extremes (syncScrollButtons) and runs the
        # rAF hover-scroll; aria-hidden throughout (keyboard scrolls via
        # focus + scroll-my-1).
        # @api private
        def scroll_button(direction)
          attrs = {
            "data-slot" => "select-scroll-#{direction}-button", "aria-hidden" => "true",
            "hidden" => true,
            "class" => Style.css(:scroll_button, class: "cn-select-scroll-#{direction}-button")
          }.merge(stimulus_attributes_for(:scroll_button))
          content_tag(:div, attrs) do
            render(Icon::Component.new(name: :"chevron-#{direction}", class: Style.css(:scroll_icon)))
          end
        end

        private

        def named?
          id.present? || @trigger_aria["label"].present? || @trigger_aria["labelledby"].present?
        end

        # Pull the trigger-bound aria-* out of the root's html attributes
        # (both flat "aria-label" and nested aria: {label:} spellings) so
        # Field's control_attributes wire the combobox, not the wrapper.
        def extract_trigger_aria!
          aria = {}.with_indifferent_access
          nested = @html_attributes.delete("aria")
          nested.each { |nested_key, nested_value| aria[nested_key] = nested_value } if nested.is_a?(Hash)
          @html_attributes.keys.grep(/\Aaria-/).each do |flat|
            aria[flat.delete_prefix("aria-")] = @html_attributes.delete(flat)
          end
          aria
        end

        def trigger_aria_attributes
          TRIGGER_ARIA_KEYS.each_with_object({}) do |key, attrs|
            attrs["aria-#{key}"] = @trigger_aria[key] unless @trigger_aria[key].nil?
          end
        end

        # The value DISPLAY: server-rendered selected-option label (no
        # FOUC), or the placeholder text; data-placeholder on the span
        # carries the placeholder so a later clear can restore it.
        def value_display
          attrs = { "data-slot" => "select-value", "class" => "cn-select-value" }
          attrs["data-placeholder"] = placeholder if placeholder.present?
          content_tag(:span, selected_label || placeholder, attrs)
        end

        def chevron
          render(Icon::Component.new(name: :"chevron-down", class: Style.css(:trigger_icon)))
        end

        # The blank option (Rails include_blank semantics, value="") rides
        # the placeholder - and is always present when no option matches,
        # so the native select never silently rests on the first option
        # while the trigger shows the placeholder.
        def native_options
          rendered = []
          if placeholder.present? || selected_label.nil?
            rendered << tag.option(placeholder.to_s, value: "", selected: selected_label.nil? || nil)
          end
          option_set.entries.each do |entry|
            rendered << tag.option(entry.label, value: entry.value,
                                                selected: entry.value == selected_value || nil,
                                                disabled: entry.disabled || nil)
          end
          safe_join(rendered)
        end

        # BOTH controllers build into ONE Attributes instance - a plain
        # Hash#merge of two would overwrite data-controller instead of
        # token-concatenating it.
        def value_string = value.to_s

        def item_wiring
          @item_wiring ||= stimulus_attributes_for(:item)
        end

        private :trigger_id, :content_id, :native_id, :option_set, :selected_value, :selected_label, :root_attributes
        private :native_select, :trigger_button, :content_attributes, :viewport_attributes, :scroll_button
      end

      # role=group with an optional heading label (aria-labelledby wired) -
      # the same item union one level down, registering its options into
      # the PARENT's option set so the native select and value display see
      # every option.
      #
      # @api private
      class Group < Poetry::Core::Component
        internal_component!
        include Helpers

        attr_reader :option_set, :selected_value, :item_wiring

        slot_doc :items, "The same item | separator union as the root, one level down."
        renders_many :items, types: {
          item: { renders: ->(**options) { item_component(**options) }, as: :item },
          separator: { renders: ->(**options) { separator_part(**options) }, as: :separator }
        }

        # heading: is the canonical keyword; label: is accepted as an alias.
        def initialize(option_set:, selected_value:, heading: nil, label: nil, item_wiring: {}, **extra_attributes)
          super(extra_attributes)
          @item_wiring = item_wiring
          @option_set = option_set
          @selected_value = selected_value
          @label_text = heading || label
        end

        def before_render
          raise ArgumentError, "Select group requires at least one item" unless items?
        end

        def call
          attrs = { "data-slot" => "select-group", "role" => "group", "class" => "cn-select-group" }
          attrs["aria-labelledby"] = label_id if @label_text
          content_tag(:div, Poetry::Core::HTML::Attributes.merged(attrs, html_attributes)) do
            safe_join([label_part, *items].compact)
          end
        end

        private

        def group_id
          @group_id ||= poetry_instance_id("poetry-select-group")
        end

        def label_id
          "#{group_id}-label"
        end

        # A styled heading, no ARIA role - the group points at it via
        # aria-labelledby.
        def label_part
          return if @label_text.blank?

          content_tag(:div, @label_text, "data-slot" => "select-label", "id" => label_id,
                                         "class" => Style.css(:label))
        end
      end
    end
  end
end
