# frozen_string_literal: true

module Poetry
  module Ui
    module Command
      # The controller identifier, declared ONCE - every data attribute
      # derives from it through the Stimulus Builder, validated against
      # the controllers manifest (no hand-written wiring strings).

      # The server-side item registry: every rendered item (DOM order)
      # lands here so option ids are server-stable ("#{id}-item-<n>" - the
      # aria-activedescendant contract) and the initial highlight (the
      # value: option, else the first enabled item) is decided in render
      # order before the input derives its activedescendant. Duplicate or
      # blank values raise at render (the base contract).
      #
      # @api private
      class ItemSet
        attr_reader :highlighted_id, :count

        def initialize(base_id:, highlight_value: nil)
          @base_id = base_id
          @highlight_value = highlight_value.presence
          @seen = Set.new
          @count = 0
          @highlighted_id = nil
        end

        # Registers one item; returns [item_id, highlighted].
        def register(value:, disabled: false)
          key = value.to_s
          raise ArgumentError, "Command item requires a non-blank value:" if key.blank?
          unless @seen.add?(key)
            raise ArgumentError, "duplicate Command item value #{key.inspect} - item values must be " \
                                 "unique within their command"
          end

          item_id = "#{@base_id}-item-#{@count}"
          @count += 1
          highlighted = highlight?(key, disabled)
          @highlighted_id = item_id if highlighted
          [item_id, highlighted]
        end

        private

        # value: given -> only that item (unless disabled; the controller's
        # connect-seat falls back client-side); no value -> first enabled.
        def highlight?(value, disabled)
          return false if @highlighted_id || disabled

          @highlight_value ? value == @highlight_value : true
        end
      end

      # Shared part builders for the item union - mixed into the root
      # Component and the nested Group so both levels render the same
      # anatomy through the same Builder. Hosts must expose #item_set.
      #
      # @api private
      module Helpers
        private

        # Hosts must also expose #item_wiring (the root Component computes
        # it from its :item declaration; Group receives it at construction)
        # so every item renders the same declared wiring.
        def item_component(**)
          Item.new(item_set: item_set, item_wiring: item_wiring, **)
        end

        # role=separator, server-rendered VISIBLE - the controller hides
        # every separator whenever the query is non-empty (cmdk parity: a
        # filtered list has no stable sections).
        def separator_part(**options)
          attrs = {
            # Decorative inside role=listbox (only option/group children
            # are valid - axe aria-required-children, the Select precedent).
            "data-slot" => "command-separator", "aria-hidden" => "true",
            "class" => Style.css(:separator, class: options.delete(:class))
          }
          content_tag(:div, nil, attrs.merge(options))
        end
      end

      # One role=option div (APG editable combobox, activedescendant
      # flavor). A part component ON PURPOSE (not an eager lambda):
      # rendering happens in DOM order, so the shared ItemSet assigns
      # server-stable ids and the initial highlight in exactly the order
      # the controller's collection walks. NO tabindex (options are never
      # DOM-focused - the activedescendant design) and NO aria-selected
      # (reserved for committed values - a bare palette has none; the
      # highlight is data-highlighted + the input's activedescendant).
      #
      # @api private
      class Item < Poetry::Core::Component
        internal_component!
        include Helpers

        attr_reader :item_set, :item_wiring

        def initialize(item_set:, value:, item_wiring: {}, **options)
          super(options)
          @item_set = item_set
          @item_wiring = item_wiring
          @value = value.to_s
          @disabled = options.delete(:disabled) || false
          @keywords = Array(options.delete(:keywords)).map(&:to_s)
          @filter_value = options.delete(:filter_value)
          @always_render = options.delete(:always_render) || false
          @shortcut = options.delete(:shortcut)
        end

        def call
          item_id, highlighted = item_set.register(value: @value, disabled: @disabled)
          attrs = {
            "id" => item_id, "data-slot" => "command-item", "role" => "option",
            "data-poetry-collection-item" => "", "data-value" => @value,
            "class" => Style.css(:item, class: html_attributes.delete(:class))
          }.merge(@item_wiring)
          attrs["data-highlighted"] = "" if highlighted
          if @disabled
            attrs["aria-disabled"] = "true"
            attrs["data-disabled"] = ""
          end
          attrs["data-keywords"] = @keywords.join(" ") if @keywords.any?
          attrs["data-filter-value"] = @filter_value if @filter_value
          attrs["data-always-render"] = "" if @always_render
          content_tag(:div, Poetry::Core::HTML::Attributes.merged(attrs, html_attributes)) do
            safe_join([label_part, shortcut_part].compact)
          end
        end

        private

        # The item's LABEL - the filter/typematch text source (shortcuts
        # excluded; icons contribute no textContent; icon-rich content
        # overrides via filter_value:/keywords:).
        def label_part
          content_tag(:span, content, "data-slot" => "command-item-text",
                                      "class" => Style.css(:item_text))
        end

        # Presentational only - Command never binds the hinted key (the
        # host recipe does); excluded from the filter text.
        def shortcut_part
          return if @shortcut.blank?

          content_tag(:span, @shortcut, "data-slot" => "command-shortcut",
                                        "class" => Style.css(:shortcut))
        end
      end

      # role=group labelled by its heading part (aria-labelledby wired) -
      # the same item union one level down, registering its items into the
      # PARENT's item set so ids and the initial highlight stay in DOM
      # order. Plain ViewComponent::Base ON PURPOSE: nested parts are
      # anatomy, not registered components.
      #
      # @api private
      class Group < Poetry::Core::Component
        internal_component!
        include Helpers

        attr_reader :item_set, :item_wiring

        renders_many :items, types: {
          item: { renders: ->(**options) { item_component(**options) }, as: :item },
          separator: { renders: ->(**options) { separator_part(**options) }, as: :separator }
        }

        def initialize(item_set:, heading:, item_wiring: {}, always_render: false, **extra_attributes)
          raise ArgumentError, "Command group requires heading: (the group's accessible name)" if heading.blank?

          super(extra_attributes)
          @item_set = item_set
          @item_wiring = item_wiring
          @heading_text = heading
          @always_render = always_render
        end

        def before_render
          raise ArgumentError, "Command group requires at least one item" unless items?
        end

        def call
          attrs = {
            "data-slot" => "command-group", "role" => "group", "aria-labelledby" => heading_id,
            "class" => Style.css(:group, class: html_attributes.delete(:class))
          }
          attrs["data-always-render"] = "" if @always_render
          content_tag(:div, Poetry::Core::HTML::Attributes.merged(attrs, html_attributes)) do
            safe_join([heading_part, *items])
          end
        end

        private

        def group_id
          @group_id ||= poetry_instance_id("poetry-command-group")
        end

        def heading_id
          "#{group_id}-heading"
        end

        # A styled heading, no ARIA role (cmdk-exact) - the group points at
        # it via aria-labelledby.
        def heading_part
          content_tag(:div, @heading_text, "data-slot" => "command-group-heading", "id" => heading_id,
                                           "class" => Style.css(:heading))
        end
      end

      # The Command palette: a filterable
      # command list - an always-visible search input over a listbox of
      # actions, filtered client-side as you type. THE NET-NEW APG BUILD
      # (no Radix primitive; shadcn wraps cmdk): the APG editable-combobox
      # pattern with aria-activedescendant - real focus stays pinned to
      # the input for the whole session, the highlighted option carries
      # data-highlighted + its server-stable id in the input's
      # aria-activedescendant, and options never get tabindex (the
      # deliberate delta vs the menus/Select family's roving focus).
      #
      # THE FILTER (poetry--core--command + helpers/filter_rank.js) is
      # deterministic substring + a 5-band rank - NOT cmdk's fuzzy scorer -
      # and HIDE-ONLY: the server renders ALL items, the controller hides
      # non-matches (hidden + data-hidden) and never reorders the DOM.
      # Activation is an EVENT (cancelable poetry:command:select), never an
      # action - the host (or Combobox, which wraps this engine) owns the
      # consequences. filter: false is the server-driven mode (cmdk
      # shouldFilter parity) - the Turbo-frame async seam.
      #
      # @example
      #   render Poetry::Ui::Command::Component.new("aria-label": "Command menu") do |command|
      #     command.with_item(value: "new-file") { "New file" }
      #     command.with_item(value: "search") { "Search" }
      #   end
      class Component < Poetry::Core::Component
        include Helpers

        AGENT_RULES = [
          "Use poetry_command - never hand-roll a filterable listbox with an input + a list and ad-hoc JS.",
          "Command items DO things; they carry no form value. Picking a value for a form is Combobox " \
          "(which wraps this) - never bind a hidden input to a bare Command.",
          "Every item needs a unique value: (ArgumentError) and gets a server id - never strip item ids " \
          "(aria-activedescendant depends on them).",
          "Never put tabindex or focus on options; never write aria-selected in a bare Command - " \
          "highlight is data-highlighted + activedescendant only.",
          "Filtering is hide-only: never reorder, remove, or re-append items to 'sort' results - " \
          "DOM order is the contract.",
          "The poetry:command:select event is the ONLY activation surface - act in a listener (or item " \
          "data-action); don't patch the controller to navigate.",
          "Long/async data: filter: false + a Turbo frame (the recipe) - don't render 5,000 items and hope.",
          "Icon-rich labels: set filter_value:/keywords: rather than stuffing hidden text into items."
        ].freeze

        # The input-bound ARIA surface: aria-label/labelledby/describedby
        # passed to the component land on the INPUT - the combobox is the
        # interactive control the label must reach - never on the root div.
        INPUT_ARIA_KEYS = %w[label labelledby describedby].freeze

        # The named? disjunction, stated statically: the command-palette
        # crash class - id-or-aria, checkable at write time.
        REQUIRES_ANY = [
          { hint: "the input's accessible name",
            options: %w[id aria-label aria-labelledby aria] }
        ].freeze

        # Custom zero-results content (defaults to t('poetry.command.empty')).
        renders_one :empty
        # Custom pending content (a spinner); the HOST toggles visibility
        # (Turbo frame events) - Command renders the part, never sets it.
        renders_one :loading

        # The item UNION: item | group (heading + items) | separator - one
        # ordered collection (interleaving preserved; items and groups are
        # part COMPONENTS so id assignment follows render/DOM order).
        renders_many :items, types: {
          item: { renders: ->(**options) { item_component(**options) }, as: :item },
          group: { renders: lambda { |**options|
            Group.new(item_set: item_set, item_wiring: item_wiring, **options)
          }, as: :group },
          separator: { renders: ->(**options) { separator_part(**options) }, as: :separator }
        }

        use_stimulus do
          on :root do
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
          # Every item (root-level and grouped) wears this - the anatomy
          # classes receive it as item_wiring at construction.
          on :item do
            controller :command do
              action :activate, on: :click
              action :pointer_highlight, on: :pointermove
            end
          end
        end

        option :filter, :boolean, default: true
        option :loop, :boolean, default: false
        option :placeholder, :string
        option :list_label, :string, default: -> { I18n.t("poetry.command.list_label") }
        option :value, :string
        option :disabled, :boolean, default: false
        option :id, :string

        part "command", "Root of the palette - the input row over the listbox, carrying the " \
                        "engine controller"
        part "command-input-wrapper", "The input row - search icon + filter input above the list"
        part "command-search-icon", "Decorative search glyph beside the input"
        part "command-input", "The role=combobox filter input - real focus stays pinned here " \
                              "for the whole session; the highlight rides aria-activedescendant"
        part "command-list", "The role=listbox holding empty/loading/items - the input's " \
                             "aria-controls target"
        part "command-empty", "Zero-matches message - rendered hidden; the controller unhides " \
                              "it when the filter pass leaves no visible items"
        part "command-loading", "Pending affordance (role=status) - rendered hidden; the HOST " \
                                "toggles it (Turbo frame events), Command never does"
        part "command-group", "role=group labelled by its heading - hidden by the controller " \
                              "when every member item is filtered out",
             states: {
               "data-always-render" => "always_render: is set - the group survives every filter pass"
             }
        part "command-group-heading", "The group heading - styled, no ARIA role (the group " \
                                      "points at it via aria-labelledby)"
        part "command-item", "One role=option action row - highlight, filtering, and " \
                             "disablement ride here (never aria-selected in a bare Command)",
             states: {
               "data-value" => "always - the item's unique value (its server-stable id follows " \
                               "registration order)",
               "data-highlighted" => "the item holds the highlight (bare; the controller " \
                                     "twin-writes it with the input's aria-activedescendant)",
               "data-disabled" => "disabled: is set (aria-disabled rides along)",
               "data-keywords" => "keywords: given - extra filter terms beyond the label",
               "data-always-render" => "always_render: is set - the item survives every filter pass",
               "data-hidden" => "the filter scored the item zero (the controller pairs it with " \
                                "hidden; never rendered server-side)"
             }
        part "command-item-text", "The item's label span - the filter/typematch text source " \
                                  "(shortcuts and icons excluded)"
        part "command-shortcut", "Presentational keyboard hint - excluded from the filter text; " \
                                 "Command never binds the hinted key"
        part "command-separator", "Decorative divider (aria-hidden) - hidden by the controller " \
                                  "whenever the query is non-empty"
        part "command-status", "The sr-only polite result-count live region - the controller " \
                               "writes the debounced count from the localized templates",
             states: {
               "data-zero" => "always - the localized zero-results template",
               "data-one" => "always - the localized one-result template",
               "data-other" => "always - the localized many-results template (a literal count " \
                               "placeholder the controller interpolates)"
             }

        def initialize(attributes = {})
          super
          @input_aria = extract_input_aria!
        end

        def before_render
          return if named?

          raise ArgumentError, "Command requires an accessible name for its input - pass 'aria-label' " \
                               "(or id: plus a visible label[for: \"<id>-input\"])"
        end

        # Stable server ids: "#{id}-input" / "#{id}-list" / "#{id}-item-<n>"
        # (aria-activedescendant NEEDS server-stable option ids).
        def base_id
          @base_id ||= id.presence || poetry_instance_id("poetry-command")
        end

        def input_id
          "#{base_id}-input"
        end

        def list_id
          "#{base_id}-list"
        end

        def item_set
          @item_set ||= ItemSet.new(base_id: base_id, highlight_value: value)
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            { "id" => base_id, "data-slot" => "command" }
              .merge(stimulus_attributes_for(:root))
              .merge(component_data_attributes)
          )
        end

        # THE combobox: aria-expanded is STATICALLY true - the listbox is
        # always rendered and visible in bare Command (Combobox flips it on
        # its trigger instead). The activedescendant is server-rendered
        # from the ItemSet (populated by the template's capture pass).
        def input_attributes
          attrs = {
            "type" => "text", "id" => input_id, "data-slot" => "command-input",
            "role" => "combobox", "aria-expanded" => "true", "aria-controls" => list_id,
            "aria-autocomplete" => "list", "autocomplete" => "off", "autocorrect" => "off",
            "spellcheck" => "false", "class" => css(:input)
          }
          attrs["placeholder"] = placeholder if placeholder.present?
          attrs["disabled"] = true if disabled
          attrs["aria-activedescendant"] = item_set.highlighted_id if item_set.highlighted_id
          attrs.merge!(stimulus_attributes_for(:input))
          attrs.merge!(input_aria_attributes)
          attrs
        end

        def list_attributes
          {
            "id" => list_id, "data-slot" => "command-list", "role" => "listbox",
            "tabindex" => "-1", "aria-label" => list_label, "class" => css(:list)
          }
        end

        # Zero-matches message - rendered hidden; the controller unhides it
        # when the filter pass leaves no visible items. No role: the sr
        # story rides the status live region.
        def empty_part
          content_tag(:div, empty? ? empty : t("poetry.command.empty"),
                      "data-slot" => "command-empty", "hidden" => true, "class" => css(:empty))
        end

        def loading_part
          content_tag(:div, "data-slot" => "command-loading", "role" => "status",
                            "hidden" => true, "class" => css(:loading)) do
            safe_join([content_tag(:span, t("poetry.command.loading"), class: css(:sr_only)),
                       loading].compact)
          end
        end

        # POETRY ADDITION: the sr-only polite result-count region - the
        # controller writes the debounced count from the LOCALIZED
        # templates carried as data attributes (data-other keeps a literal
        # %{count} placeholder), so the engine stays i18n-free.
        def status_part
          content_tag(:span, nil,
                      "data-slot" => "command-status", "role" => "status", "aria-live" => "polite",
                      "class" => css(:status),
                      "data-zero" => t("poetry.command.results", count: 0),
                      "data-one" => t("poetry.command.results", count: 1),
                      "data-other" => t("poetry.command.results.other", count: "%{count}")) # rubocop:disable Style/FormatStringToken
        end

        private

        def named?
          id.present? || @input_aria["label"].present? || @input_aria["labelledby"].present?
        end

        # Pull the input-bound aria-* out of the root's html attributes
        # (both flat "aria-label" and nested aria: {label:} spellings) so
        # the accessible name wires the combobox, not the wrapper.
        def extract_input_aria!
          aria = {}.with_indifferent_access
          nested = @html_attributes.delete("aria")
          nested.each { |nested_key, nested_value| aria[nested_key] = nested_value } if nested.is_a?(Hash)
          @html_attributes.keys.grep(/\Aaria-/).each do |flat|
            aria[flat.delete_prefix("aria-")] = @html_attributes.delete(flat)
          end
          aria
        end

        def input_aria_attributes
          INPUT_ARIA_KEYS.each_with_object({}) do |key, attrs|
            attrs["aria-#{key}"] = @input_aria[key] unless @input_aria[key].nil?
          end
        end

        def item_wiring
          @item_wiring ||= stimulus_attributes_for(:item)
        end
      end
    end
  end
end
