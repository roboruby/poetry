# frozen_string_literal: true

module Poetry
  module Ui
    # Combobox family: the searchable select - a trigger, a filterable
    # listbox popup, and a native-select form story.
    module Combobox
      # The placement vocabularies, declared ONCE at module level - shared
      # by the validations and the part-state declarations.
      SIDES = %i[top right bottom left].freeze
      # The closed vocabulary for the align axis.
      ALIGNS = %i[start center end].freeze
      # The closed vocabulary for the reading-direction axis.
      DIRS = %i[ltr rtl].freeze

      # The server-side option registry: collects every option in render
      # order with unique non-blank values, keeps labels for the native
      # <select> and the value display, assigns the server-stable option
      # ids ("#{id}-item-<n>") that aria-activedescendant depends on, and
      # seats the initial highlight (the selected option, else the first
      # enabled item). Duplicate or blank values raise at render.
      #
      # @api private
      class OptionSet
        # One registered option: value, label, disabled.
        # @api private
        Entry = Struct.new(:value, :label, :disabled)

        attr_reader :entries, :highlighted_id

        def initialize(base_id:, highlight_value: nil)
          @base_id = base_id
          @highlight_value = highlight_value.presence
          @entries = []
          @seen = Set.new
          @highlighted_id = nil
        end

        # Registers one option; returns [item_id, highlighted].
        def register(value:, label:, disabled: false)
          key = value.to_s
          raise ArgumentError, "Combobox item requires a non-blank value:" if key.blank?
          unless @seen.add?(key)
            raise ArgumentError, "duplicate Combobox option value #{key.inspect} - option values must be " \
                                 "unique within their combobox"
          end

          item_id = "#{@base_id}-item-#{@entries.size}"
          @entries << Entry.new(key, label, disabled)
          highlighted = highlight?(key, disabled)
          @highlighted_id = item_id if highlighted
          [item_id, highlighted]
        end

        def label_for(value)
          entries.find { |entry| entry.value == value }&.label
        end

        private

        # A selected value seats the highlight on ITS option (unless
        # disabled; the controller's open-seed falls back client-side);
        # no value -> first enabled (Command's rule).
        def highlight?(value, disabled)
          return false if @highlighted_id || disabled

          @highlight_value ? value == @highlight_value : true
        end
      end

      # Shared part builders for the option union - mixed into the root
      # Component and the nested Group so both levels render the same
      # anatomy through the same Builder. Hosts must expose #option_set
      # (the shared OptionSet) and #selected_value.
      #
      # @api private
      module Helpers
        private

        def item_component(**)
          Item.new(option_set: option_set, selected_value: selected_value, **)
        end

        # The engine's separator part (Command::Style verbatim) - hidden by
        # the controller whenever the query is non-empty.
        def separator_part(**options)
          attrs = {
            # aria-hidden, never role=separator: inside role=listbox a
            # separator role is flagged (the select/command axe rule).
            "data-slot" => "combobox-separator", "aria-hidden" => "true",
            "class" => Command::Style.css(:separator, class: options.delete(:class))
          }
          content_tag(:div, nil, attrs.merge(options))
        end

        # COMBOBOX-OWNED addition onto each combobox-item: the
        # committed-value check - TRAILING (ms-auto), not Select's
        # absolute gutter. Server-rendered always; the item's
        # data-selected absence hides it in CSS while unselected.
        def item_indicator
          content_tag(:span, "data-slot" => "combobox-item-indicator",
                             "class" => Style.css(:item_indicator, class: Style.css(:item_indicator_state))) do
            render(Icon::Component.new(name: :check, class: Style.css(:indicator_check)))
          end
        end
      end

      # One role=option div carrying BOTH meanings: it stays a valid
      # COMMAND item
      # (data-value + data-poetry-collection-item + the engine's
      # activate/pointerHighlight actions + keywords/filter_value/
      # always_render, NO tabindex - activedescendant, never DOM focus)
      # AND wears Select's committed-value surface (aria-selected +
      # data-selected twin-written together, never separately, plus the
      # trailing indicator). A part component ON PURPOSE: rendering
      # happens in DOM order, so the shared OptionSet assigns server-
      # stable ids and registers native <option>s in exactly the order
      # the listbox renders - top level or grouped.
      #
      # @api private
      class Item < Poetry::Core::Component
        internal_component!
        include Helpers

        attr_reader :option_set, :selected_value

        def initialize(option_set:, selected_value:, value:, **options)
          super(options)
          @option_set = option_set
          @selected_value = selected_value
          @value = value.to_s
          @disabled = options.delete(:disabled) || false
          @text_value = options.delete(:text_value)
          @keywords = Array(options.delete(:keywords)).map(&:to_s)
          @filter_value = options.delete(:filter_value)
          @always_render = options.delete(:always_render) || false
        end

        def call
          label_html = content || "".html_safe
          plain_label = (@text_value.presence || ActionView::Base.full_sanitizer.sanitize(label_html.to_s)).squish
          item_id, highlighted = option_set.register(value: @value, label: plain_label, disabled: @disabled)

          # multiple passes the committed LIST - selection is ARRAY
          # INCLUSION; single stays the scalar equality.
          selected = if selected_value.is_a?(Array)
                       selected_value.include?(@value)
                     else
                       selected_value.present? && @value == selected_value
                     end
          attrs = {
            "id" => item_id, "data-slot" => "combobox-item", "role" => "option",
            "data-poetry-collection-item" => "", "data-value" => @value,
            "aria-selected" => selected.to_s,
            "class" => Command::Style.css(:item, class: [Style.css(:item_fill),
                                                         html_attributes.delete(:class)].compact.join(" "))
          }.merge(stimulus_attributes(:command) do |command|
            command.with_action(:activate, on: :click)
            command.with_action(:pointer_highlight, on: :pointermove)
          end)
          # The selected state: bare data-selected on the committed
          # option, NOTHING while unselected (absence IS the state).
          attrs["data-selected"] = "" if selected
          attrs["data-highlighted"] = "" if highlighted
          if @disabled
            attrs["aria-disabled"] = "true"
            attrs["data-disabled"] = ""
          end
          attrs["data-text-value"] = @text_value if @text_value
          attrs["data-keywords"] = @keywords.join(" ") if @keywords.any?
          attrs["data-filter-value"] = @filter_value if @filter_value
          attrs["data-always-render"] = "" if @always_render
          content_tag(:div, Poetry::Core::HTML::Attributes.merged(attrs, html_attributes)) do
            safe_join([content_tag(:span, label_html, "data-slot" => "combobox-item-text",
                                                      "class" => Style.css(:item_text)),
                       item_indicator])
          end
        end
      end

      # role=group labelled by its heading part (Command's group shape,
      # the source's combobox geometry: unpadded, the label themed) -
      # the same item union one level down, registering its options into
      # the PARENT's option set so ids, the native <select>, and the
      # value display see every option in DOM order. Kept internal ON
      # PURPOSE: nested parts are anatomy, not registered components.
      #
      # @api private
      class Group < Poetry::Core::Component
        internal_component!
        include Helpers

        attr_reader :option_set, :selected_value

        slot_doc :items, "The group's members: with_item options and with_separator dividers, interleaved in " \
                         "declaration order."
        renders_many :items, types: {
          item: { renders: ->(**options) { item_component(**options) }, as: :item },
          separator: { renders: ->(**options) { separator_part(**options) }, as: :separator }
        }

        def initialize(option_set:, selected_value:, heading:, always_render: false, **extra_attributes)
          raise ArgumentError, "Combobox group requires heading: (the group's accessible name)" if heading.blank?

          super(extra_attributes)
          @option_set = option_set
          @selected_value = selected_value
          @heading_text = heading
          @always_render = always_render
        end

        def before_render
          raise ArgumentError, "Combobox group requires at least one item" unless items?
        end

        def call
          attrs = { "data-slot" => "combobox-group", "role" => "group", "aria-labelledby" => heading_id }
          # The group is unpadded and hookless (the list carries the
          # inset) - a class attribute only when the caller passes one.
          classes = Style.css(:group, class: html_attributes.delete(:class))
          attrs["class"] = classes if classes.present?
          attrs["data-always-render"] = "" if @always_render
          content_tag(:div, Poetry::Core::HTML::Attributes.merged(attrs, html_attributes)) do
            safe_join([heading_part, *items])
          end
        end

        private

        def group_id
          @group_id ||= poetry_instance_id("poetry-combobox-group")
        end

        def heading_id
          "#{group_id}-heading"
        end

        def heading_part
          content_tag(:div, @heading_text, "data-slot" => "combobox-label", "id" => heading_id,
                                           "class" => Style.css(:label))
        end
      end

      # A searchable select: a button that opens a popup holding a filter
      # input and a listbox of options, committing the chosen value to a
      # visually hidden native <select> that is the form's source of
      # truth. Options are server-rendered and filtered client-side as
      # you type; the selected option's label shows in the trigger.
      #
      # Opening focuses the filter input (the selected option is
      # highlighted and scrolled into view, not focused); Tab while open
      # closes WITHOUT committing; a printable key on the closed trigger
      # opens the popup and seeds the filter.
      #
      # With multiple: true, value: takes a LIST, a chips field (chips in
      # value order plus the filter input inline) replaces the trigger,
      # the native <select multiple> posts name[], the listbox turns
      # aria-multiselectable, and selection TOGGLES with the popup
      # staying open.
      #
      # @example
      #   render Poetry::Ui::Combobox::Component.new(name: "framework", "aria-label" => "Framework") do |combobox|
      #     combobox.with_item(value: "rails") { "Ruby on Rails" }
      #     combobox.with_item(value: "hanami") { "Hanami" }
      #   end
      class Component < Poetry::Core::Component
        include Helpers

        # The trigger-bound ARIA surface: Field's control_attributes (and
        # bare aria-label usage) land on the TRIGGER - the combobox is the
        # interactive control the label must reach - never on the root div.
        TRIGGER_ARIA_KEYS = %w[label labelledby describedby invalid required].freeze

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Use poetry_combobox (f.poetry_combobox in forms) - never hand-wire Popover+Command+hidden-input; " \
          "this component IS that wiring, with the form story done right.",
          "Combobox picks VALUES. Filter-then-ACT is bare Command; short known lists are Select; free text " \
          "is Input.",
          "Every Combobox MUST be named (Field label via id: or aria-label) - a nameless bare combobox " \
          "fails at render.",
          "NEVER write aria-selected from highlight logic (position is data-highlighted + " \
          "aria-activedescendant); NEVER write the display without the native select first - the commit " \
          "pipeline does all of it; agents patching DOM must too.",
          "Async options: filter: false + the Turbo-frame ?q= recipe - AND the frame must render the twin " \
          "native <option> for every committable item (the recipe's one hard rule).",
          "multiple: true is the multi-select/chips mode: value: takes an ARRAY, the native <select " \
          "multiple> posts name[] (the [] is appended for you), selection TOGGLES with the popup " \
          "staying open, and chips replace the trigger - never fake multi with hidden inputs.",
          "Do not put interactive elements inside options (an option IS the interactive unit).",
          "Deselection in single mode is include_blank (a visible blank option) or show_clear: (the " \
          "trigger-side X - single mode only), never a re-click toggle - " \
          "committing the already-selected value closes without change. In multiple, re-committing " \
          "IS the deselect gesture (chip-remove is its pointer twin)."
        ].freeze

        # The required slots, stated statically so static checks can flag
        # a missing item without rendering.
        REQUIRED_SLOTS = { item: "at least one item" }.freeze

        slot_doc :trigger, "Optional custom trigger content rendered BEFORE the value span (rare); the component " \
                           "owns role=combobox + the aria wiring + the chevrons regardless, so composition cannot " \
                           "drop the contract."
        renders_one :trigger

        slot_doc :empty, "Custom zero-results content (defaults to t('poetry.combobox.empty'))."
        renders_one :empty
        slot_doc :loading, "Custom pending content (a spinner); the HOST toggles visibility (Turbo frame events) - " \
                           "the part renders hidden (Command parity)."
        renders_one :loading

        slot_doc :items, "The option UNION forwarded to the embedded command list: item | group (heading + items) | " \
                         "separator - one ordered collection (interleaving preserved; items and groups are part " \
                         "COMPONENTS so option registration follows render/DOM order)."
        renders_many :items, types: {
          item: { renders: ->(**options) { item_component(**options) }, as: :item },
          group: {
            renders: lambda { |**options|
              Group.new(option_set: option_set, selected_value: selected_value, **options)
            },
            as: :group
          },
          separator: { renders: ->(**options) { separator_part(**options) }, as: :separator }
        }

        use_stimulus do
          on :root do
            controller :combobox do
              register
              value :open
              value :value, from: :value_payload
              value :modal
              value :multiple, if: :multiple
            end
            # multiple mounts the command engine on the ROOT (the inline
            # input sits outside the popup); single keeps it on the
            # popup's command part.
            controller :command, if: :multiple do
              register
              value :filter
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
            controller :combobox do
              action :toggle, on: :click
              action :trigger_keydown, on: :keydown
            end
            controller(:popper) { target :anchor }
          end
          # multiple: the chips frame replaces the trigger as the anchor.
          on :chips do
            controller(:combobox) { action :chips_pointerdown, on: :mousedown }
            controller(:popper) { target :anchor }
          end
          # multiple: both engines' keyboard maps ride the one input.
          on :inline_input do
            controller :command do
              action :filter_input, on: :input
              action :keydown, on: :keydown
            end
            controller(:combobox) { action :input_keydown, on: :keydown }
          end
          on :content do
            controller(:popper) { target :content }
          end
          # single-mode: the embedded engine root inside the popup.
          on :command_part do
            controller :command do
              register
              value :filter
              value :loop
            end
          end
          on :input do
            controller :command do
              action :filter_input, on: :input
              action :keydown, on: :keydown
            end
          end
          on :item do
            controller :command do
              action :activate, on: :click
              action :pointer_highlight, on: :pointermove
            end
          end
          on :native do
            controller(:combobox) { action :native_changed, on: :change }
          end
          on :clear do
            controller(:combobox) { action :clear, on: :click }
          end
          on :chip do
            controller(:combobox) { action :chip_keydown, on: :keydown }
          end
          on :chip_remove do
            controller(:combobox) { action :remove_chip, on: :click }
          end
        end

        # The operate surface: what an in-page agent may do to a rendered
        # combobox (registered per instance, opt-in - see poetry-agent).
        tool :set_value,
             description: "Select the option whose value matches; pass an empty string to select nothing.",
             params: { value: { type: "string", required: true, description: "The option value to select." } },
             executes: %i[combobox set_value],
             mutating: true
        tool :clear,
             description: "Clear the current selection.",
             executes: %i[combobox clear],
             mutating: true

        option :value, :string, doc: "The committed value; with multiple:, an array of values."
        option :name, :string, doc: "The form field name on the native <select>; multiple: appends [] for you."
        option :placeholder, :string,
               doc: "Shown in the value display (multiple: in the inline input) while nothing is committed."
        option :search_placeholder, :string, doc: "Placeholder for the popup's filter input (single mode)."
        option :id, :string, doc: "The trigger's DOM id - the Field label target; every other part id derives from it."
        option :open, :boolean, default: false, doc: "Server-renders the popup open."
        option :required, :boolean, default: false, doc: "Forwards to the native <select> for constraint validation."
        option :disabled, :boolean, default: false,
                                    doc: "Disables the trigger, the filter input, and the native select."
        option :multiple, :boolean, default: false,
                                    doc: "Multi-select mode: value: becomes LIST-capable (single stays the scalar), " \
                                         "the trigger is replaced by the chips field, the native <select multiple> " \
                                         "posts name[], selection toggles without closing."
        option :modal, :boolean, default: false,
                                 doc: "DEFAULT FALSE - popover semantics (Tab-out closes, no scrim). true restores " \
                                      "the focus-scope trap for dialog-critical pickers."
        option :show_clear, :boolean, default: false,
                                      doc: "Single mode only: the trigger-side deselection X - swaps in over the " \
                                           "chevrons while a value is committed and commits the blank value, so the " \
                                           "cleared state serializes as \"\"."
        option :filter, :boolean, default: true,
                                  doc: "Forwarded to the embedded engine: false = server-driven options (the async " \
                                       "Turbo-frame recipe)."
        option :loop, :boolean, default: false, doc: "Wraps arrow-key highlight movement past either end of the list."
        option :side, :symbol, default: :bottom,
                               doc: "The popup's preferred side of the trigger; collisions may flip it."
        option :align, :symbol, default: :start, doc: "The popup's alignment along the trigger's edge."
        option :side_offset, :integer, default: 4, doc: "Gap in px between the trigger and the popup."
        option :align_offset, :integer, default: 0, doc: "Skid in px along the aligned edge."
        option :avoid_collisions, :boolean, default: true, doc: "Flips/shifts the popup to stay inside the viewport."
        option :dir, :symbol, doc: "Writing-direction override (ltr/rtl) stamped on the root."
        option :width, :string,
               doc: "The trigger width utility class; the popup ALWAYS tracks the trigger's measured width, so one " \
                    "knob sizes both surfaces. nil resolves to the dictionary's default (w-50)."

        validates :side, inclusion: { in: SIDES }
        validates :align, inclusion: { in: ALIGNS }
        validates :dir, inclusion: { in: DIRS }, allow_nil: true

        part "combobox", "Root wrapper carrying both controllers (combobox + popper) and the " \
                         "optional dir attribute"
        part "combobox-native", "The visually-hidden native <select> - the serialization truth " \
                                "(Select's decision verbatim); plumbing, never styled or targeted"
        part "combobox-trigger", "The role=combobox button (the demo's outline Button) the field " \
                                 "label reaches - value display and chevrons ride inside",
             states: {
               "data-placeholder" => "no option is committed (bare; the controller toggles it " \
                                     "on every commit)",
               "data-popup-open" => "the popup is open (bare while open, absent while closed - " \
                                    "the controller flips it with the open state)"
             }
        part "combobox-value", "The value display span - the selected option's label, or the placeholder",
             states: {
               "data-placeholder" => "placeholder: is given - carries the placeholder text so " \
                                     "the controller can restore it"
             }
        part "combobox-chip-input", "The inline filter input beside the chips (multiple: only) - the one " \
                                    "typing surface; the source's chip input"
        part "combobox-content", "The popper-positioned popup housing the embedded Command " \
                                 "anatomy - open/closed and the resolved placement ride here",
             states: {
               "data-open" => "popup is open (the controller flips the pair at runtime)",
               "data-closed" => "popup is closed or animating out (the server-rendered state)",
               "data-chips" => "multiple: - chips mode; the popup's minimum width follows the chips field",
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
               "--anchor-width" => "popper - the trigger's measured width (the popup width " \
                                   "tracks it - one knob, two surfaces)",
               "--anchor-height" => "popper - the trigger's measured height"
             }
        part "combobox-clear", "The show_clear: deselection X - a trigger sibling seated over " \
                               "the chevron slot; pressing it commits the blank value and " \
                               "returns focus to the trigger. Wears the html hidden attribute " \
                               "while no value is committed (the controller flips it on every " \
                               "commit; the chevron swap derives from that one flip in CSS)"
        part "combobox-command", "The embedded engine root - Command's anatomy rendered here against its " \
                                 "own controller (composition at the markup contract)"
        part "combobox-input-wrapper", "The input row - search icon + filter input above the list"
        part "combobox-search-icon", "Decorative search glyph beside the input"
        part "combobox-input", "The filter input (role=combobox) - the typing session and " \
                               "aria-activedescendant live here. Single: in the popup with its own " \
                               "accessible name; multiple: INLINE in the chips frame (the " \
                               "input-inside layout), where the field label reaches it",
             states: {
               "data-popup-open" => "multiple: the popup is open (bare while open, absent while " \
                                    "closed - the input carries the flip; single's trigger owns it)"
             }
        part "combobox-list", "THE role=listbox - the aria-controls target of both combobox roles"
        part "combobox-empty", "Zero-matches message - rendered hidden; the engine unhides it " \
                               "when the filter pass leaves no visible items"
        part "combobox-group", "role=group labelled by its heading - hidden by the engine when " \
                               "every member item is filtered out"
        part "combobox-label", "The group heading - styled, no ARIA role (the group " \
                               "points at it via aria-labelledby)"
        part "combobox-item", "One role=option div wearing BOTH meanings - a Command item " \
                              "(filtering + highlight) AND Select's committed-value surface",
             states: {
               "data-value" => "always - the option's committable value (the native <option> twin)",
               "data-selected" => "the option is committed (bare; absent while unselected - the " \
                                  "controller twin-writes it with aria-selected)",
               "data-highlighted" => "the item holds the activedescendant highlight (the server " \
                                     "seeds it; the engine moves it with the input's " \
                                     "aria-activedescendant)",
               "data-disabled" => "disabled: is set (aria-disabled rides along)",
               "data-hidden" => "the filter scored the item zero (the engine pairs it with " \
                                "hidden; never rendered server-side)"
             }
        part "combobox-item-text", "The option's label span - the filter/typematch text source"
        part "combobox-item-indicator", "The trailing committed-value check (ms-auto per the " \
                                        "demo) - the parent item's data-selected absence hides it"
        part "combobox-separator", "Decorative divider (aria-hidden) - hidden by the engine " \
                                   "whenever the query is non-empty"
        part "combobox-loading", "Pending affordance (role=status) - rendered hidden; the HOST " \
                                 "unhides it around async refills"
        part "combobox-status", "The engine's sr-only polite result-count live region",
             states: {
               "data-zero" => "always - the localized zero-results template",
               "data-one" => "always - the localized one-result template",
               "data-other" => "always - the localized many-results template (a literal count " \
                               "placeholder the controller interpolates)"
             }
        part "combobox-chips", "The chips FIELD frame (multiple: only) - the popper anchor " \
                               "replacing the trigger; chips + the inline input flex-wrap inside, " \
                               "and role=toolbar rides it only while it holds >=1 chip",
             states: {
               "data-placeholder" => "the selection is empty (bare; the controller flips it on " \
                                     "every commit - the toolbar role departs with it)",
               "data-disabled" => "disabled: is set - every chip mutation is gated",
               "data-remove-label" => "always - the localized chip-remove template (a literal " \
                                      "label placeholder the controller interpolates for " \
                                      "client-built chips)"
             }
        part "combobox-chip", "One committed value (multiple: only) - a div taking REAL focus " \
                              "(tabindex=-1, styled by :focus-visible; chips NEVER wear " \
                              "data-highlighted), named by its value text, holding the remove button",
             states: {
               "data-value" => "always - the chip's committed value (the native <option> twin)",
               "data-disabled" => "disabled: is set (chip focus is blocked entirely)"
             }
        part "combobox-chip-remove", "The chip's native remove button (tabindex=-1, labelled " \
                                     "'Remove <label>') - a press removes the value and is never " \
                                     "a chips-area press"

        # Normalizes the multiple-mode list value before the typed
        # attribute write.
        # @api private
        def initialize(attributes = {})
          # multiple: value: is LIST-capable (single keeps the scalar
          # :string cast) - the array is normalized ahead of the typed
          # attribute write, List-cast semantics (scalars adopt as
          # one-element lists).
          if attributes.values_at(:multiple, "multiple").any?
            raw = attributes.delete(:value) { attributes.delete("value") }
            @list_value = Array(raw).map(&:to_s).select(&:present?).uniq
          end

          super
          @trigger_aria = extract_trigger_aria!
        end

        # Enforces the item, naming, and mode-compatibility contracts.
        # @api private
        def before_render
          raise ArgumentError, "Combobox requires at least one item (with_item / with_group)" unless items?

          if show_clear && multiple
            raise ArgumentError, "show_clear: is single-mode only - multiple already has per-chip " \
                                 "removal and the closed-popup Escape wipe"
          end

          return if named?

          raise ArgumentError, "Combobox requires an accessible name - compose with a Field label " \
                               "(id: + label[for: id]) or pass 'aria-label'"
        end

        # The Field-targetable id lands on the TRIGGER (label[for=id]
        # click-focuses the combobox); every other part derives from it -
        # server-generated, portal-safe, stream-safe. Stable ids:
        # '#{id}' trigger / '#{id}-content' / '#{id}-list' (the
        # aria-controls target of BOTH combobox roles) / '#{id}-native' /
        # '#{id}-input' / '#{id}-item-<n>'.
        # @api private
        def trigger_id
          @trigger_id ||= id.presence || poetry_instance_id("poetry-combobox")
        end

        # The popup panel's id.
        # @api private
        def content_id
          "#{trigger_id}-content"
        end

        # The listbox's id - both combobox roles point aria-controls here.
        # @api private
        def list_id
          "#{trigger_id}-list"
        end

        # The hidden native select's id.
        # @api private
        def native_id
          "#{trigger_id}-native"
        end

        # The popup filter input's id (single mode).
        # @api private
        def input_id
          "#{trigger_id}-input"
        end

        # The shared option registry for this render.
        # @api private
        def option_set
          # multiple seeds the highlight on the FIRST committed value (the
          # scalar rule, list-shaped).
          @option_set ||= OptionSet.new(base_id: trigger_id,
                                        highlight_value: multiple ? selected_values.first : selected_value)
        end

        # single: the committed scalar; multiple: the committed LIST (array
        # inclusion is the selection test everywhere downstream - items,
        # native options, chips).
        # @api private
        def selected_value
          @selected_value ||= multiple ? selected_values : value.presence.to_s
        end

        # The committed list (multiple mode; empty otherwise).
        # @api private
        def selected_values
          @list_value || []
        end

        # The committed option's label for the value display (single mode).
        # @api private
        def selected_label
          option_set.label_for(selected_value) if !multiple && selected_value.present?
        end

        # Attributes for the root wrapper.
        # @api private
        def root_attributes
          root = { "data-slot" => "combobox" }
          root["dir"] = dir.to_s if dir
          html_attributes.merge_if_not_set(
            root.merge(root_stimulus_attributes).merge(component_data_attributes)
          )
        end

        # The serialization truth: a real <select> carrying
        # name/required/disabled and ALL options with selected - visually
        # hidden (sr-only, painted) and out of both trees (aria-hidden +
        # tabindex=-1). The change action is the autofill-adoption path.
        # multiple flips the multiple attribute and posts the Rails array
        # convention (name[], appended unless the given name already ends
        # with it).
        # @api private
        def native_select
          attrs = {
            "id" => native_id, "data-slot" => "combobox-native",
            "aria-hidden" => "true", "tabindex" => "-1", "class" => Style.css(:native)
          }
          attrs["name"] = native_name if name.present?
          attrs["multiple"] = true if multiple
          attrs["required"] = true if required
          attrs["disabled"] = true if disabled
          attrs.merge!(stimulus_attributes_for(:native))
          content_tag(:select, native_options, attrs)
        end

        # The width utility the trigger/chips carry - the option, or the
        # dictionary default (w-50).
        # @api private
        def width_classes = width || css(:default_width)

        # The combobox-role trigger button: aria-controls points at the
        # LISTBOX (the a11y-true relationship the controller resolves the
        # popup through), aria-haspopup=listbox names the popup kind, and
        # there is NO aria-autocomplete here - the typing session belongs
        # to the popup input.
        # @api private
        def trigger_button
          attrs = {
            "id" => trigger_id, "data-slot" => "combobox-trigger", "type" => "button",
            "role" => "combobox", "aria-expanded" => open.to_s, "aria-controls" => list_id,
            "aria-haspopup" => "listbox",
            "class" => classnames(css(:trigger), width_classes)
          }
          # The trigger state: bare data-popup-open while open, NO
          # attribute while closed (absence IS the state).
          attrs["data-popup-open"] = "" if open
          attrs["data-placeholder"] = "" unless selected_label
          attrs["disabled"] = true if disabled
          attrs.merge!(trigger_stimulus_attributes)
          attrs.merge!(trigger_aria_attributes)
          content_tag(:button, attrs) do
            safe_join([leading_content, chevrons])
          end
        end

        # A custom trigger slot (leading icon) GROUPS with the value display
        # - three bare children under justify-between would strand the text
        # mid-row (icon left, text center, chevrons right). Slot-less
        # triggers keep the flat two-child markup.
        # @api private
        def leading_content
          return value_display unless trigger?

          content_tag(:span, safe_join([trigger, value_display]), "class" => Style.css(:trigger_leading))
        end

        # The chips FIELD (multiple: - replaces the trigger with an
        # input-inside layout): the popper anchor frame holding one chip
        # per committed value IN VALUE ORDER, the inline filter input
        # (data-slot=command-input - the engine's markup contract), and
        # the <template> chip skeleton the controller clones for
        # client-side commits. role=toolbar rides the frame only while it
        # holds chips; an empty selection wears data-placeholder instead.
        # @api private
        def chips_frame
          attrs = {
            "data-slot" => "combobox-chips",
            "data-remove-label" => t("poetry.combobox.remove", label: "%{label}"), # rubocop:disable Style/FormatStringToken
            "class" => classnames(css(:chips), width_classes)
          }
          attrs["role"] = "toolbar" if selected_values.any?
          attrs["data-placeholder"] = "" if selected_values.empty?
          attrs["data-disabled"] = "" if disabled
          attrs.merge!(chips_stimulus_attributes)
          content_tag(:div, attrs) do
            chips = selected_values.map { |chip_value| chip_part(chip_value) }
            safe_join(chips + [inline_input, chip_template])
          end
        end

        # The popup (popper CONTENT; focus-scope + dismissable tokens are
        # appended by the controller on open - NEVER roving-focus, the
        # embedded Command is activedescendant). No role: the listbox
        # lives inside.
        # @api private
        def content_attributes
          attrs = {
            "id" => content_id, "data-slot" => "combobox-content", "tabindex" => "-1",
            (open ? "data-open" : "data-closed") => "",
            # Initial placement, re-resolved live by popper on open.
            "data-side" => side, "data-align" => align,
            "class" => css(:content)
          }.merge(stimulus_attributes_for(:content))
          attrs["hidden"] = true unless open
          attrs
        end

        # The committed value(s) as the controller's value payload.
        # @api private
        def value_payload = multiple ? selected_values : value.to_s

        # The embedded engine root with filter/loop forwarded - the
        # composition boundary: this component renders Command's anatomy
        # against the engine's own controller, reused unchanged. Nesting
        # Command::Component instead would collide ids (its root id would
        # duplicate the trigger's), could not seat the indicator inside
        # each item, and could not retune the input's height.
        # @api private
        def command_attributes
          { "data-slot" => "combobox-command", "class" => Command::Style.css }
            .merge(stimulus_attributes_for(:command_part))
        end

        # The popup's filter input (Command's contract, retuned to h-9):
        # its OWN accessible name - t('.filter_label'), distinct
        # from the field label naming the trigger. aria-expanded is
        # statically true (the listbox is always rendered inside the
        # popup; the TRIGGER carries the dynamic flip).
        # @api private
        def input_attributes
          attrs = {
            "type" => "text", "id" => input_id, "data-slot" => "combobox-input",
            "role" => "combobox", "aria-expanded" => "true", "aria-controls" => list_id,
            "aria-autocomplete" => "list", "autocomplete" => "off", "autocorrect" => "off",
            "spellcheck" => "false", "aria-label" => t("poetry.combobox.filter_label"),
            "class" => Command::Style.css(:input, class: css(:input_fill))
          }
          # The source stamps chips mode on the popup (its min-width follows the field).
          attrs["data-chips"] = "true" if multiple
          attrs["placeholder"] = search_placeholder if search_placeholder.present?
          attrs["disabled"] = true if disabled
          attrs["aria-activedescendant"] = option_set.highlighted_id if option_set.highlighted_id
          attrs.merge!(stimulus_attributes_for(:input))
          attrs
        end

        # THE listbox - the aria-controls target of both combobox roles
        # (the trigger resolves the popup through it). multiple declares
        # aria-multiselectable. Wears the combobox's own list rule (the
        # inset rides the list; the parts wear the source's combobox
        # vocabulary - the engine resolves either family's slot names).
        # @api private
        def list_attributes
          attrs = {
            "id" => list_id, "data-slot" => "combobox-list", "role" => "listbox",
            "tabindex" => "-1", "aria-label" => t("poetry.command.list_label"),
            "class" => css(:list)
          }
          attrs["aria-multiselectable"] = "true" if multiple
          attrs
        end

        # Zero-matches message - rendered hidden; the engine unhides it
        # when the filter pass leaves no visible items.
        # @api private
        def empty_part
          content_tag(:div, empty? ? empty : t("poetry.combobox.empty"),
                      "data-slot" => "combobox-empty", "hidden" => true, "class" => Command::Style.css(:empty))
        end

        # Pending affordance (role=status) - rendered hidden; the HOST
        # unhides it around async refills (Command's part, shared keys).
        # @api private
        def loading_part
          content_tag(:div, "data-slot" => "combobox-loading", "role" => "status",
                            "hidden" => true, "class" => Command::Style.css(:loading)) do
            safe_join([content_tag(:span, t("poetry.command.loading"), class: Command::Style.css(:sr_only)),
                       loading].compact)
          end
        end

        # The engine's sr-only polite result-count region (localized
        # templates carried as data attributes - Command's keys, shared).
        # @api private
        def status_part
          content_tag(:span, nil,
                      "data-slot" => "combobox-status", "role" => "status", "aria-live" => "polite",
                      "class" => Command::Style.css(:status),
                      "data-zero" => t("poetry.command.results", count: 0),
                      "data-one" => t("poetry.command.results", count: 1),
                      "data-other" => t("poetry.command.results.other", count: "%{count}")) # rubocop:disable Style/FormatStringToken
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
        # carries the placeholder so the controller can restore it.
        def value_display
          attrs = { "data-slot" => "combobox-value", "class" => css(:value) }
          attrs["data-placeholder"] = placeholder if placeholder.present?
          content_tag(:span, selected_label || placeholder, attrs)
        end

        # The double chevron is the combobox tell (Select wears
        # chevron-down). show_clear adds the swap class: the chevron
        # goes invisible (keeping its box) while the sibling X is showable.
        def chevrons
          classes = classnames(Style.css(:trigger_icon), (Style.css(:trigger_icon_swap) if show_clear))
          render(Icon::Component.new(name: :"chevrons-up-down", class: classes))
        end

        # The show_clear: X - a SIBLING of the trigger (button-in-button is
        # invalid HTML), absolutely seated over the chevron slot. Server
        # renders the truthful initial state (hidden with no value); the
        # controller flips it on every commit.
        def clear_button
          attrs = {
            "data-slot" => "combobox-clear", "type" => "button",
            "aria-label" => t("poetry.combobox.clear"), "class" => css(:clear)
          }
          attrs["hidden"] = true unless selected_label
          attrs["disabled"] = true if disabled
          attrs.merge!(stimulus_attributes_for(:clear))
          content_tag(:button, attrs) do
            render(Icon::Component.new(name: :x, class: Style.css(:clear_icon)))
          end
        end

        # One chip: a div taking REAL focus (tabindex=-1, styled by
        # :focus-visible - NO data-highlighted here), named by its value
        # text, holding the native remove button. nil value = the blank
        # skeleton the <template> ships for the controller.
        def chip_part(chip_value = nil)
          label = chip_value && (option_set.label_for(chip_value) || chip_value)
          attrs = {
            "data-slot" => "combobox-chip", "tabindex" => "-1", "class" => css(:chip)
          }
          attrs["data-value"] = chip_value if chip_value
          attrs["aria-label"] = label if label
          # aria-disabled is the truth AND the axe contrast exemption - a
          # div can't carry native disabled, so without it the dimmed chip
          # reads as failing text.
          attrs["aria-disabled"] = "true" if disabled
          attrs["data-disabled"] = "" if disabled
          attrs.merge!(stimulus_attributes_for(:chip))
          content_tag(:div, attrs) do
            safe_join([label, chip_remove_part(label)].compact)
          end
        end

        # ChipRemove: a NATIVE button (tabindex=-1) labelled "Remove
        # <label>" via I18n, so every chip's remove affordance has an
        # accessible name.
        def chip_remove_part(label)
          attrs = {
            "data-slot" => "combobox-chip-remove", "type" => "button", "tabindex" => "-1",
            "class" => css(:chip_remove)
          }
          attrs["aria-label"] = t("poetry.combobox.remove", label: label) if label
          attrs["disabled"] = true if disabled
          attrs.merge!(stimulus_attributes_for(:chip_remove))
          content_tag(:button, attrs) do
            render(Icon::Component.new(name: :x, class: Style.css(:chip_remove_icon)))
          end
        end

        # The blank chip skeleton the controller clones per client-side
        # commit - SERVER markup stays the single source of chip anatomy.
        def chip_template
          content_tag(:template, chip_part)
        end

        def inline_input
          tag.input(**Poetry::Core::HTML::Attributes.new(inline_input_attributes).to_attributes)
        end

        # The inline filter input (multiple): the ONE typing surface - the
        # Field-targetable id lands HERE (no trigger exists), aria-expanded
        # is DYNAMIC (the input sits outside the popup, unlike single's
        # always-rendered listbox), and the input NEVER mirrors selection
        # text (the placeholder rides it; chips are the value display).
        def inline_input_attributes
          attrs = {
            "type" => "text", "id" => trigger_id, "data-slot" => "combobox-chip-input",
            "role" => "combobox", "aria-expanded" => open.to_s, "aria-controls" => list_id,
            "aria-haspopup" => "listbox", "aria-autocomplete" => "list", "autocomplete" => "off",
            "autocorrect" => "off", "spellcheck" => "false", "class" => css(:chip_input)
          }
          # The input state: bare data-popup-open while open, NO
          # attribute while closed (absence IS the state).
          attrs["data-popup-open"] = "" if open
          attrs["placeholder"] = placeholder if placeholder.present?
          attrs["disabled"] = true if disabled
          attrs["aria-activedescendant"] = option_set.highlighted_id if open && option_set.highlighted_id
          attrs.merge!(inline_input_stimulus_attributes)
          attrs.merge!(trigger_aria_attributes)
          attrs
        end

        # The frame carries the popper anchor AND the combobox press action
        # - one Attributes instance (the Accordion lesson, via Select).
        def chips_stimulus_attributes
          stimulus_attributes_for(:chips)
        end

        # BOTH controllers' keyboard maps ride the one input: the engine's
        # filter/arrows/Enter, then the shell's chips map (Backspace /
        # ArrowLeft / reopen / the closed-popup Escape wipe).
        def inline_input_stimulus_attributes
          stimulus_attributes_for(:inline_input)
        end

        # The blank option (Rails include_blank semantics, value="") rides
        # the placeholder - and is always present when no option matches,
        # so the native select never silently rests on the first option
        # while the trigger shows the placeholder (Select-exact). multiple
        # has no blank option (an empty multi-select just posts nothing);
        # selected flags flip to array inclusion.
        def native_options
          rendered = []
          # show_clear forces the blank option even while a value is
          # committed - the cleared state must serialize as "" (a native
          # select with no blank option cannot rest on nothing).
          if !multiple && (placeholder.present? || selected_label.nil? || show_clear)
            rendered << tag.option(placeholder.to_s, value: "", selected: selected_label.nil? || nil)
          end
          option_set.entries.each do |entry|
            rendered << tag.option(entry.label, value: entry.value,
                                                selected: native_selected?(entry.value) || nil,
                                                disabled: entry.disabled || nil)
          end
          safe_join(rendered)
        end

        def native_name
          return name unless multiple

          name.end_with?("[]") ? name : "#{name}[]"
        end

        def native_selected?(entry_value)
          multiple ? selected_values.include?(entry_value) : entry_value == selected_value
        end

        # BOTH controllers build into ONE Attributes instance - a plain
        # Hash#merge of two would overwrite data-controller instead of
        # token-concatenating it (the Accordion lesson, via Select).
        # multiple adds a THIRD: the command engine mounts on the ROOT (the
        # inline input sits outside the popup, so the engine must scope
        # over both) - single keeps it on the popup's command part.
        def root_stimulus_attributes
          stimulus_attributes_for(:root)
        end

        def trigger_stimulus_attributes
          stimulus_attributes_for(:trigger)
        end

        private :trigger_id, :content_id, :list_id, :native_id, :input_id, :option_set
        private :selected_label, :root_attributes, :native_select, :width_classes, :trigger_button
        private :leading_content, :chips_frame, :content_attributes, :value_payload, :command_attributes
        private :input_attributes, :list_attributes, :empty_part, :loading_part, :status_part
      end
    end
  end
end
