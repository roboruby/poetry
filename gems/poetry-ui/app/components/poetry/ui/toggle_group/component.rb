# frozen_string_literal: true

module Poetry
  module Ui
    module ToggleGroup
      # Last of the toggle family (ToggleGroup): a set
      # of Toggle-styled items under one value machine and one roving tab
      # stop - the Accordion composition, second consumer. Two machines on
      # one root: poetry--core--toggle-group owns the pressed-values set
      # (single: {v}<->{} deselect-to-empty; multiple: XOR) and
      # poetry--core--roving-focus in its DEFAULT tabindex-managing mode
      # owns the keyboard (one Tab stop, arrows move focus WITHOUT
      # selecting - a deliberate Radix deviation from APG radio, kept so
      # browsing options never fires effects).
      #
      # The source-verified role split: type=single renders role=radiogroup
      # with role=radio items + aria-checked (aria-pressed STRIPPED);
      # type=multiple renders role=toolbar with aria-pressed items. Items
      # are DUMB buttons (no per-item poetry--core--pressed - one owner, no
      # event soup), styled by the shared Toggle::Style dictionary.
      #
      # NO form participation (Toggle's rule at group scale): a
      # single-select that must submit is a RadioGroup; a multi-select that
      # must submit is a checkbox group.
      class Component < Poetry::Core::Component
        GROUP = %i[poetry core toggle_group].freeze
        ROVING = %i[poetry core roving_focus].freeze
        TYPES = %i[single multiple].freeze
        ORIENTATIONS = %i[horizontal vertical].freeze

        AGENT_RULES = [
          "Use poetry_toggle_group - never hand-assemble Toggles with your own exclusivity logic.",
          "ToggleGroup is UI state, NOT form data: submitting single-select -> RadioGroup; submitting " \
          "multi-select -> Checkbox group. No name: exists; don't route around it.",
          "Every item MUST have a unique value: (ArgumentError on duplicates); icon-only items MUST " \
          "pass label: (state-invariant).",
          "Name the group via label: - a nameless radiogroup/toolbar fails the audit.",
          "Exclusive view/mode switching that shows PANELS is Tabs (aria-selected + tabpanels), not a " \
          "single ToggleGroup.",
          "Never mix vocabularies: single items carry aria-checked, multiple carry aria-pressed - the " \
          "controller enforces it; agents patching DOM must too.",
          "single deselects to empty by re-press (Radix-exact) - if your UI needs always-one-selected, " \
          "handle the empty change in the host."
        ].freeze

        # The axes are Toggle's, consumed through the shared dictionary;
        # the root cascades them to items as data attributes (ROOT WINS -
        # the source's context.variant || item rule).
        style :variant, default: :default, required: true, variants: Toggle::Component::VARIANTS
        style :size, default: :default, required: true, variants: Toggle::Component::SIZES

        option :type, :symbol, default: :single
        # single: the pressed item's value. ArgumentError with :multiple.
        option :value, :string
        # multiple: the pressed items' values. ArgumentError with :single.
        option :values, :list, default: -> { [] }
        # 0 = SEGMENTED: joined corners + collapsed outline borders (the
        # source's data-[spacing=0] chain); >0 = free-standing with a gap.
        option :spacing, :integer, default: 0
        # Roving axis + data-orientation; horizontal is the styled path.
        option :orientation, :symbol, default: :horizontal
        # Disables every item (Radix root disabled).
        option :disabled, :boolean, default: false
        # The group accessible name -> aria-label (poetry addition: shadcn
        # ships nameless radiogroups/toolbars).
        option :label, :string

        # The Accordion value/values API precedent verbatim: the wrong pair
        # for the type is unrepresentable, not ignored.
        def initialize(attributes = {})
          type = (attributes[:type] || attributes["type"] || :single).to_sym
          raise ArgumentError, "ToggleGroup type must be :single or :multiple" unless TYPES.include?(type)

          if type == :single && attributes.values_at(:values, "values").any?
            raise ArgumentError, "values: is the :multiple API - single takes value: (one pressed item)"
          end
          if type == :multiple && attributes.values_at(:value, "value").any?
            raise ArgumentError, "value: is the :single API - multiple takes values: (an array)"
          end

          super
        end

        validates :orientation, inclusion: { in: ORIENTATIONS }

        # One item per toggle: DUMB buttons under the group machine - no
        # per-item controller, data-action -> group#toggle, styled by the
        # shared Toggle dictionary + the item overrides.
        renders_many :items, lambda { |value:, label: nil, disabled: false, **options, &block|
          item_value = register_item_value!(value)
          content = capture(&block)
          ensure_item_name!(content, label, item_value)
          on = pressed_values.include?(item_value)
          item_disabled = disabled || self.disabled

          attrs = {
            type: "button", class: item_classes(options.delete(:class)),
            "data-slot" => "toggle-group-item", "data-poetry-collection-item" => "",
            "data-value" => item_value,
            "data-variant" => variant, "data-size" => size, "data-spacing" => spacing
          }
          # Base UI presence boolean: pressed -> bare data-pressed,
          # unpressed -> attribute absent (never data-pressed=false).
          attrs["data-pressed"] = "" if on
          # The role/vocabulary split (Radix-exact: single strips
          # aria-pressed and wears the radio vocabulary).
          if single?
            attrs["role"] = "radio"
            attrs["aria-checked"] = on.to_s
          else
            attrs["aria-pressed"] = on.to_s
          end
          if item_disabled
            attrs[:disabled] = true
            attrs["data-disabled"] = "" # the roving-focus collection filter
          end
          attrs["aria-label"] = label if label.present?
          attrs.merge!(stimulus_attributes(GROUP) { |group| group.with_action(:toggle, on: :click) })

          content_tag(:button, content, attrs.merge(options))
        }

        def before_render
          raise ArgumentError, "ToggleGroup requires at least one with_item" unless items?

          return if named?

          # Lint-level warning, not an error: a radiogroup/toolbar SHOULD
          # have an accessible name.
          Rails.logger&.warn(
            "poetry ToggleGroup: nameless #{single? ? "radiogroup" : "toolbar"} - give it label: (or aria-labelledby)"
          )
        end

        def single?
          type != :multiple
        end

        def pressed_values
          @pressed_values ||= (single? ? Array(value) : Array(values)).compact.map(&:to_s)
        end

        def root_attributes
          attrs = {
            "role" => single? ? "radiogroup" : "toolbar",
            "data-slot" => "toggle-group",
            "data-variant" => variant, "data-size" => size, "data-spacing" => spacing,
            "data-orientation" => orientation, "style" => "--gap: #{spacing}"
          }
          attrs["aria-label"] = label if label.present?
          attrs["data-disabled"] = "" if disabled
          html_attributes.merge_if_not_set(
            attrs.merge(root_stimulus_attributes).merge(component_data_attributes)
          )
        end

        private

        def register_item_value!(value)
          @item_values ||= Set.new
          item_value = value.to_s
          unless @item_values.add?(item_value)
            raise ArgumentError, "duplicate ToggleGroup item value #{item_value.inspect} - values key the set machine"
          end

          item_value
        end

        def ensure_item_name!(content, label, item_value)
          return if label.present? || content.to_s.gsub(/<[^>]+>/, " ").strip.present?

          raise ArgumentError,
                "icon-only ToggleGroup item #{item_value.inspect} requires label: (the accessible name, " \
                "state-invariant)"
        end

        def named?
          aria = html_attributes["aria"] || {}
          label.present? ||
            html_attributes["aria-label"].present? || html_attributes["aria-labelledby"].present? ||
            aria["label"].present? || aria["labelledby"].present?
        end

        # Shared-not-copied: the item's variant/size classes come from
        # Toggle's dictionary (the toggleVariants import graph); this
        # component's dictionary contributes only the item overrides. The
        # merger collapses conflicts exactly as the source's cn() does
        # (px-3 wins, min-w-0 wins).
        def item_classes(extra)
          classnames(Toggle::Style.css(variant: variant, size: size), css(:item), extra)
        end

        # BOTH controllers build into ONE Attributes instance - a plain
        # Hash#merge of two would overwrite data-controller instead of
        # token-concatenating it (the Accordion lesson).
        def root_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          group = Poetry::Core::Stimulus::Builder.new(GROUP, attrs)
          group.register_controller
          group.with_value(:type, type)
          roving = Poetry::Core::Stimulus::Builder.new(ROVING, attrs)
          roving.register_controller
          # DEFAULT tabindex-managing mode (contrast Accordion's
          # manage_tabindex: false): one tab stop, pressed item preferred.
          roving.with_value(:orientation, orientation)
          roving.with_value(:loop, true)
          roving.with_action(:keydown, on: :keydown)
          attrs.to_attributes
        end

        def stimulus_attributes(controller)
          attrs = Poetry::Core::HTML::Attributes.new
          yield Poetry::Core::Stimulus::Builder.new(controller, attrs)
          attrs.to_attributes
        end
      end
    end
  end
end
