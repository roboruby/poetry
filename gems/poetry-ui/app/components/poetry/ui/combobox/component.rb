# frozen_string_literal: true

module Poetry
  module Ui
    module Combobox
      # The controller identifiers, declared ONCE - every data attribute
      # derives from them through the Stimulus Builder, validated against
      # the controllers manifest (no hand-written wiring strings).
      COMBOBOX = %i[poetry core combobox].freeze
      COMMAND = %i[poetry core command].freeze
      POPPER = %i[poetry core popper].freeze
      SIDES = %i[top right bottom left].freeze
      ALIGNS = %i[start center end].freeze
      DIRS = %i[ltr rtl].freeze

      # The server-side option registry: Select's OptionSet (unique
      # non-blank values, labels for the native <select> and the value
      # display) fused with Command's ItemSet (server-stable option ids
      # "#{id}-item-<n>" - the aria-activedescendant contract - and the
      # initial highlight seat: the selected option, else the first
      # enabled item). Duplicate or blank values raise at render (the
      # base contract).
      class OptionSet
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
        # no value -> first enabled (Command's rule verbatim).
        def highlight?(value, disabled)
          return false if @highlighted_id || disabled

          @highlight_value ? value == @highlight_value : true
        end
      end

      # Shared part builders for the option union - mixed into the root
      # Component and the nested Group so both levels render the same
      # anatomy through the same Builder. Hosts must expose #option_set
      # (the shared OptionSet) and #selected_value.
      module Helpers
        private

        def combobox_stimulus
          attrs = Poetry::Core::HTML::Attributes.new
          yield Poetry::Core::Stimulus::Builder.new(COMBOBOX, attrs)
          attrs.to_attributes
        end

        def command_stimulus
          attrs = Poetry::Core::HTML::Attributes.new
          yield Poetry::Core::Stimulus::Builder.new(COMMAND, attrs)
          attrs.to_attributes
        end

        def popper_stimulus
          attrs = Poetry::Core::HTML::Attributes.new
          yield Poetry::Core::Stimulus::Builder.new(POPPER, attrs)
          attrs.to_attributes
        end

        def item_component(**)
          Item.new(option_set: option_set, selected_value: selected_value, **)
        end

        # The engine's separator part (Command::Style verbatim) - hidden by
        # the controller whenever the query is non-empty (cmdk parity).
        def separator_part(**options)
          attrs = {
            "data-slot" => "command-separator", "role" => "separator",
            "class" => Command::Style.css(:separator, class: options.delete(:class))
          }
          content_tag(:div, nil, attrs.merge(options))
        end

        # COMBOBOX-OWNED addition onto each command-item: the
        # committed-value check - TRAILING ms-auto per the demo, not
        # Select's absolute gutter. Server-rendered always; the item's
        # data-selected absence hides it while unselected (attribute-driven,
        # replacing the demo's opacity-by-value-equality JSX).
        def item_indicator
          content_tag(:span, "data-slot" => "combobox-item-indicator",
                             "class" => Style.css(:item_indicator, class: Style.css(:item_indicator_state))) do
            render(Icon::Component.new(name: :check, class: Style.css(:indicator_check)))
          end
        end
      end

      # One role=option div carrying BOTH meanings ([[CL Component -
      # Combobox]]'s two-meanings rule): it stays a valid COMMAND item
      # (data-value + data-poetry-collection-item + the engine's
      # activate/pointerHighlight actions + keywords/filter_value/
      # always_render, NO tabindex - activedescendant, never DOM focus)
      # AND wears Select's committed-value surface (aria-selected +
      # data-selected twin-written together, never separately, plus the
      # trailing indicator). A part component ON PURPOSE: rendering
      # happens in DOM order, so the shared OptionSet assigns server-
      # stable ids and registers native <option>s in exactly the order
      # the listbox renders - top level or grouped.
      class Item < ViewComponent::Base
        include Helpers

        attr_reader :option_set, :selected_value

        def initialize(option_set:, selected_value:, value:, **options)
          super()
          @option_set = option_set
          @selected_value = selected_value
          @value = value.to_s
          @disabled = options.delete(:disabled) || false
          @text_value = options.delete(:text_value)
          @keywords = Array(options.delete(:keywords)).map(&:to_s)
          @filter_value = options.delete(:filter_value)
          @always_render = options.delete(:always_render) || false
          @extra_attributes = options
        end

        def call
          label_html = content || "".html_safe
          plain_label = (@text_value.presence || ActionView::Base.full_sanitizer.sanitize(label_html.to_s)).squish
          item_id, highlighted = option_set.register(value: @value, label: plain_label, disabled: @disabled)

          selected = selected_value.present? && @value == selected_value
          attrs = {
            "id" => item_id, "data-slot" => "command-item", "role" => "option",
            "data-poetry-collection-item" => "", "data-value" => @value,
            "aria-selected" => selected.to_s,
            "class" => Command::Style.css(:item, class: @extra_attributes.delete(:class))
          }.merge(command_stimulus do |command|
            command.with_action(:activate, on: :click)
            command.with_action(:pointer_highlight, on: :pointermove)
          end)
          # Base UI selected state: bare data-selected on the committed
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
          content_tag(:div, attrs.merge(@extra_attributes)) do
            safe_join([content_tag(:span, label_html, "data-slot" => "command-item-text"),
                       item_indicator])
          end
        end
      end

      # role=group labelled by its heading part (Command's group shape
      # verbatim) - the same item union one level down, registering its
      # options into the PARENT's option set so ids, the native <select>,
      # and the value display see every option in DOM order. Plain
      # ViewComponent::Base ON PURPOSE: nested parts are anatomy, not
      # registered components.
      class Group < ViewComponent::Base
        include Helpers

        attr_reader :option_set, :selected_value

        renders_many :items, types: {
          item: { renders: ->(**options) { item_component(**options) }, as: :item },
          separator: { renders: ->(**options) { separator_part(**options) }, as: :separator }
        }

        def initialize(option_set:, selected_value:, heading:, always_render: false, **extra_attributes)
          raise ArgumentError, "Combobox group requires heading: (the group's accessible name)" if heading.blank?

          super()
          @option_set = option_set
          @selected_value = selected_value
          @heading_text = heading
          @always_render = always_render
          @extra_attributes = extra_attributes
        end

        def before_render
          raise ArgumentError, "Combobox group requires at least one item" unless items?
        end

        def call
          attrs = {
            "data-slot" => "command-group", "role" => "group", "aria-labelledby" => heading_id,
            "class" => Command::Style.css(:group, class: @extra_attributes.delete(:class))
          }
          attrs["data-always-render"] = "" if @always_render
          content_tag(:div, attrs.merge(@extra_attributes)) do
            safe_join([heading_part, *items])
          end
        end

        private

        def group_id
          @group_id ||= "poetry-combobox-group-#{SecureRandom.hex(4)}"
        end

        def heading_id
          "#{group_id}-heading"
        end

        def heading_part
          content_tag(:div, @heading_text, "data-slot" => "command-group-heading", "id" => heading_id,
                                           "class" => Command::Style.css(:heading))
        end
      end

      # The Combobox (Combobox): Select's shell x
      # Command's engine - the shadcn DOCS composition (Button
      # role=combobox + Popover + Command) made server-native. The
      # root/trigger/native-select/value-display are Select's contract
      # shapes verbatim (a combobox-role button anchor, a visually-hidden
      # server-rendered native <select> as THE serialization truth, the
      # native-first commit pipeline in poetry--core--combobox); the popup
      # is the full embedded Command anatomy (input + filtered listbox),
      # rendered HERE against Command::Style + the poetry--core--command
      # controller rather than by nesting Command::Component - composition
      # AT THE MARKUP CONTRACT: nesting the component would collide ids
      # (Command's root id would duplicate the trigger's), could not seat
      # the indicator inside each item, and could not retune the input to
      # the demo's h-9. The engine controller and its event contract are
      # reused unchanged; the two controllers compose via
      # poetry:command:select only (zero shared code, greps fence both
      # directions).
      #
      # THE THREE DELIBERATE DELTAS vs Select (each pinned by tests):
      # open focuses the INPUT (a typing session - APG editable combobox;
      # the selected option gets highlight + scrollIntoView, not focus);
      # Tab while open CLOSES WITHOUT COMMIT (Popover semantics, modal:
      # false default); a printable key on the closed trigger OPENS and
      # SEEDS the filter (no closed-trigger typeahead-commit).
      class Component < Poetry::Core::Component
        include Helpers

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
          "In forms, always f.poetry_combobox; multiple: raises - multi-select/chips is not shipped (do " \
          "not fake it with hidden inputs).",
          "Do not put interactive elements inside options (an option IS the interactive unit).",
          "Deselection is include_blank (a visible blank option), never a re-click toggle - committing " \
          "the already-selected value closes without change."
        ].freeze

        # The trigger-bound ARIA surface: Field's control_attributes (and
        # bare aria-label usage) land on the TRIGGER - the combobox is the
        # interactive control the label must reach - never on the root div.
        TRIGGER_ARIA_KEYS = %w[label labelledby describedby invalid required].freeze

        option :value, :string
        option :name, :string
        option :placeholder, :string
        option :search_placeholder, :string
        option :id, :string
        option :open, :boolean, default: false
        option :required, :boolean, default: false
        option :disabled, :boolean, default: false
        # DEFAULT FALSE - Popover semantics (Tab-out closes, no scrim); the
        # delta vs Select's modal: true. true restores the focus-scope trap
        # for dialog-critical pickers.
        option :modal, :boolean, default: false
        # Forwarded to the embedded engine: false = server-driven options
        # (the async Turbo-frame recipe).
        option :filter, :boolean, default: true
        option :loop, :boolean, default: false
        option :side, :symbol, default: :bottom
        option :align, :symbol, default: :start
        option :side_offset, :integer, default: 4
        option :avoid_collisions, :boolean, default: true
        option :dir, :symbol
        # The trigger width utility (the demo 200px as its scale spelling,
        # w-50 - DesignLint off-scale-arbitrary; the popup ALWAYS
        # tracks it via the anchor-width binding - one knob, two surfaces).
        option :width, :string, default: "w-50"

        validates :side, inclusion: { in: SIDES }
        validates :align, inclusion: { in: ALIGNS }
        validates :dir, inclusion: { in: DIRS }, allow_nil: true

        # Optional custom trigger content rendered BEFORE the value span
        # (rare); the component owns role=combobox + the aria wiring + the
        # chevrons regardless, so composition cannot drop the contract.
        renders_one :trigger

        # Custom zero-results content (defaults to t('poetry.combobox.empty')).
        renders_one :empty

        # The option UNION forwarded to the embedded command list: item |
        # group (heading + items) | separator - one ordered collection
        # (interleaving preserved; items and groups are part COMPONENTS so
        # option registration follows render/DOM order).
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

        def initialize(attributes = {})
          if attributes.key?(:multiple) || attributes.key?("multiple")
            raise ArgumentError, "Combobox does not support multiple: - multi-select/chips is not shipped " \
                                 "(see the deferred Base UI surface)"
          end

          super
          @trigger_aria = extract_trigger_aria!
        end

        def before_render
          raise ArgumentError, "Combobox requires at least one item (with_item / with_group)" unless items?

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
        def trigger_id
          @trigger_id ||= id.presence || "poetry-combobox-#{SecureRandom.hex(4)}"
        end

        def content_id
          "#{trigger_id}-content"
        end

        def list_id
          "#{trigger_id}-list"
        end

        def native_id
          "#{trigger_id}-native"
        end

        def input_id
          "#{trigger_id}-input"
        end

        def option_set
          @option_set ||= OptionSet.new(base_id: trigger_id, highlight_value: selected_value)
        end

        def selected_value
          @selected_value ||= value.presence.to_s
        end

        def selected_label
          option_set.label_for(selected_value) if selected_value.present?
        end

        def root_attributes
          root = { "data-slot" => "combobox" }
          root["dir"] = dir.to_s if dir
          html_attributes.merge_if_not_set(
            root.merge(root_stimulus_attributes).merge(component_data_attributes)
          )
        end

        # The serialization truth (Select's decision verbatim): a real
        # <select> carrying name/required/disabled and ALL options with
        # selected - visually hidden (sr-only, painted) and out of both
        # trees (aria-hidden + tabindex=-1). The change action is the
        # autofill-adoption path (nativeChanged).
        def native_select
          attrs = {
            "id" => native_id, "data-slot" => "combobox-native",
            "aria-hidden" => "true", "tabindex" => "-1", "class" => Style.css(:native)
          }
          attrs["name"] = name if name.present?
          attrs["required"] = true if required
          attrs["disabled"] = true if disabled
          attrs.merge!(combobox_stimulus { |combobox| combobox.with_action(:native_changed, on: :change) })
          content_tag(:select, native_options, attrs)
        end

        # The combobox-role trigger (the demo's Button variant=outline):
        # aria-controls points at the LISTBOX (the a11y-true relationship
        # the controller resolves the popup through), aria-haspopup=listbox
        # names the popup kind, and there is NO aria-autocomplete here -
        # the typing session belongs to the popup input (the double-
        # combobox kept for source parity).
        def trigger_button
          attrs = {
            "id" => trigger_id, "data-slot" => "combobox-trigger", "type" => "button",
            "role" => "combobox", "aria-expanded" => open.to_s, "aria-controls" => list_id,
            "aria-haspopup" => "listbox",
            "class" => classnames(css(:trigger), width)
          }
          # Base UI trigger state: bare data-popup-open while open, NO
          # attribute while closed (absence IS the state).
          attrs["data-popup-open"] = "" if open
          attrs["data-placeholder"] = "" unless selected_label
          attrs["disabled"] = true if disabled
          attrs.merge!(trigger_stimulus_attributes)
          attrs.merge!(trigger_aria_attributes)
          content_tag(:button, attrs) do
            safe_join([trigger, value_display, chevrons].compact)
          end
        end

        # The popup (popper CONTENT; focus-scope + dismissable tokens are
        # appended by the controller on open - NEVER roving-focus, the
        # embedded Command is activedescendant). No role: the listbox
        # lives inside.
        def content_attributes
          attrs = {
            "id" => content_id, "data-slot" => "combobox-content", "tabindex" => "-1",
            (open ? "data-open" : "data-closed") => "",
            # Initial placement, re-resolved live by popper on open.
            "data-side" => side, "data-align" => align,
            "class" => css(:content)
          }.merge(popper_stimulus { |popper| popper.with_target(:content) })
          attrs["hidden"] = true unless open
          attrs
        end

        # The embedded engine root: its OWN poetry--core--command
        # controller with filter/loop forwarded - the composition boundary
        # (this component renders Command's anatomy; the engine controller
        # is reused unchanged).
        def command_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          command = Poetry::Core::Stimulus::Builder.new(COMMAND, attrs)
          command.register_controller
          command.with_value(:filter, filter)
          command.with_value(:loop, loop)
          { "data-slot" => "command", "class" => Command::Style.css }.merge(attrs.to_attributes)
        end

        # The popup's filter input (Command's contract at the demo's h-9
        # scale): its OWN accessible name - t('.filter_label'), distinct
        # from the field label naming the trigger. aria-expanded is
        # statically true (the listbox is always rendered inside the
        # popup; the TRIGGER carries the dynamic flip).
        def input_attributes
          attrs = {
            "type" => "text", "id" => input_id, "data-slot" => "command-input",
            "role" => "combobox", "aria-expanded" => "true", "aria-controls" => list_id,
            "aria-autocomplete" => "list", "autocomplete" => "off", "autocorrect" => "off",
            "spellcheck" => "false", "aria-label" => t("poetry.combobox.filter_label"),
            "class" => Command::Style.css(:input, class: css(:input_scale))
          }
          attrs["placeholder"] = search_placeholder if search_placeholder.present?
          attrs["disabled"] = true if disabled
          attrs["aria-activedescendant"] = option_set.highlighted_id if option_set.highlighted_id
          attrs.merge!(command_stimulus do |command|
            command.with_action(:filter_input, on: :input)
            command.with_action(:keydown, on: :keydown)
          end)
          attrs
        end

        # THE listbox - the aria-controls target of both combobox roles
        # (the trigger resolves the popup through it).
        def list_attributes
          {
            "id" => list_id, "data-slot" => "command-list", "role" => "listbox",
            "tabindex" => "-1", "aria-label" => t("poetry.command.list_label"),
            "class" => Command::Style.css(:list)
          }
        end

        # Zero-matches message - rendered hidden; the engine unhides it
        # when the filter pass leaves no visible items.
        def empty_part
          content_tag(:div, empty? ? empty : t("poetry.combobox.empty"),
                      "data-slot" => "command-empty", "hidden" => true, "class" => Command::Style.css(:empty))
        end

        # The engine's sr-only polite result-count region (localized
        # templates carried as data attributes - Command's keys, shared).
        def status_part
          content_tag(:span, nil,
                      "data-slot" => "command-status", "role" => "status", "aria-live" => "polite",
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

        # The double chevron is the combobox tell (source-exact; Select
        # wears chevron-down).
        def chevrons
          render(Icon::Component.new(name: :"chevrons-up-down", class: Style.css(:trigger_icon)))
        end

        # The blank option (Rails include_blank semantics, value="") rides
        # the placeholder - and is always present when no option matches,
        # so the native select never silently rests on the first option
        # while the trigger shows the placeholder (Select-exact).
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
        # token-concatenating it (the Accordion lesson, via Select).
        def root_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          combobox = Poetry::Core::Stimulus::Builder.new(COMBOBOX, attrs)
          combobox.register_controller
          combobox.with_value(:open, open)
          combobox.with_value(:value, value.to_s)
          combobox.with_value(:modal, modal)
          popper = Poetry::Core::Stimulus::Builder.new(POPPER, attrs)
          popper.register_controller
          popper.with_value(:side, side)
          popper.with_value(:align, align)
          popper.with_value(:side_offset, side_offset)
          popper.with_value(:avoid_collisions, avoid_collisions)
          attrs.to_attributes
        end

        def trigger_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          combobox = Poetry::Core::Stimulus::Builder.new(COMBOBOX, attrs)
          combobox.with_action(:toggle, on: :click)
          combobox.with_action(:trigger_keydown, on: :keydown)
          popper = Poetry::Core::Stimulus::Builder.new(POPPER, attrs)
          popper.with_target(:anchor)
          attrs.to_attributes
        end
      end
    end
  end
end
