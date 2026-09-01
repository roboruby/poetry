# frozen_string_literal: true

module Poetry
  module Ui
    # Exclusive or multi-select toggle sets.
    module ToggleGroup
      # A set of Toggle-styled buttons under one value: type: :single
      # keeps at most one pressed (re-pressing deselects to empty),
      # :multiple toggles each item independently. The group is one Tab
      # stop - arrow keys move focus between items WITHOUT selecting, so
      # browsing options never fires effects; Space/Enter press the
      # focused item. Single groups render role=radiogroup with
      # aria-checked items; multiple groups render role=toolbar with
      # aria-pressed items.
      #
      # A ToggleGroup is UI state, not form data: a single-select that
      # must submit is a RadioGroup, a multi-select that must submit is a
      # checkbox group. spacing: 0 renders the classic segmented control.
      #
      # @example A text-alignment switcher
      #   render Poetry::Ui::ToggleGroup::Component.new(value: "left", label: "Text alignment") do |group|
      #     group.with_item(value: "left", label: "Align left") { icon(:"align-left") }
      #     group.with_item(value: "center", label: "Align center") { icon(:"align-center") }
      #   end
      class Component < Poetry::Core::Component
        # The closed vocabulary for the type axis.
        TYPES = %i[single multiple].freeze
        # The closed vocabulary for the orientation axis.
        ORIENTATIONS = %i[horizontal vertical].freeze

        # Projected into the registry, llms.txt, and the agent surface.
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
          "single deselects to empty by re-press - if your UI needs always-one-selected, " \
          "handle the empty change in the host."
        ].freeze

        # The same facts the before_render raise enforces, stated statically:
        # poetry check flags the omission without rendering.
        REQUIRED_SLOTS = { item: "at least one item" }.freeze

        renders_many :items,
                     doc: "Declares one item: value: (unique - duplicates raise), label: (required when icon-only), " \
                          "disabled:; the block is the content. Pressed state comes from value:/values:.",
                     renders: lambda { |value:, label: nil, disabled: false, **options, &block|
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
                       # Pressed is a bare presence attribute: data-pressed when on,
                       # absent when off (never data-pressed=false).
                       attrs["data-pressed"] = "" if on
                       # The role/vocabulary split: single wears the radio vocabulary
                       # (aria-checked), never aria-pressed.
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
                       attrs.merge!(stimulus_attributes_for(:item))

                       content_tag(:button, content, Poetry::Core::HTML::Attributes.merged(attrs, options))
                     }

        use_stimulus do
          on :root do
            controller :toggle_group do
              register
              value :type
            end
            controller :roving_focus do
              register
              # DEFAULT tabindex-managing mode (contrast Accordion's
              # manage_tabindex: false).
              value :orientation
              value :loop, true
              action :keydown, on: :keydown
            end
          end
          on :item do
            controller(:toggle_group) { action :toggle, on: :click }
          end
        end

        style :variant, default: :default, required: true, variants: Toggle::Component::VARIANTS,
                        doc: "The shared Toggle variant axis, cascaded from the root to every item (root wins)."
        style :size, default: :default, required: true, variants: Toggle::Component::SIZES,
                     doc: "The shared Toggle size axis, cascaded from the root to every item (root wins)."

        option :type, :symbol, default: :single,
                               doc: ":single keeps at most one item pressed; :multiple toggles items independently."
        option :value, :string, doc: "single: the pressed item's value. ArgumentError with :multiple."
        option :values, :list, default: -> { [] },
                               doc: "multiple: the pressed items' values. ArgumentError with :single."
        option :spacing, :integer, default: 2,
                                   doc: "0 = the classic segmented control (joined corners, collapsed outline " \
                                        "borders); >0 = free-standing items separated by that gap step."
        option :orientation, :symbol, default: :horizontal,
                                      doc: "The roving axis; :vertical stacks the items and flips the arrow keys."
        option :disabled, :boolean, default: false, doc: "Disables every item in the group."
        option :label, :string,
               doc: "The group's accessible name (aria-label) - a nameless radiogroup/toolbar logs a lint warning."

        validates :orientation, inclusion: { in: ORIENTATIONS }

        part "toggle-group", "The role=radiogroup (single) / role=toolbar (multiple) root - the " \
                             "value-set machine and roving focus ride here; the axes cascade to items",
             states: {
               "data-variant" => { condition: "the shared Toggle variant (root wins)",
                                   values: Toggle::Component::VARIANTS.map(&:to_s) },
               "data-size" => { condition: "the shared Toggle size (root wins)",
                                values: Toggle::Component::SIZES.map(&:to_s) },
               "data-spacing" => "the gap step - 0 is the segmented chain (joined corners), >0 free-standing",
               "data-orientation" => { condition: "the roving axis", values: ORIENTATIONS.map(&:to_s) },
               "data-disabled" => "the whole group is disabled (disables every item)"
             },
             vars: {
               "--gap" => "the item gap, set inline from spacing: - the root's gap utility consumes it"
             }
        part "toggle-group-item", "One dumb <button> under the group machine - Toggle-styled, no " \
                                  "per-item controller",
             states: {
               "data-pressed" => "pressed (bare presence boolean - absent when off; the controller " \
                                 "rederives the type-correct aria attribute from it)",
               "data-disabled" => "the item (or the whole group) is disabled - the roving-focus " \
                                  "collection filter",
               "data-value" => "the item's key in the value set (always present, unique)",
               "data-variant" => { condition: "cascaded from the root",
                                   values: Toggle::Component::VARIANTS.map(&:to_s) },
               "data-size" => { condition: "cascaded from the root",
                                values: Toggle::Component::SIZES.map(&:to_s) },
               "data-spacing" => "cascaded from the root - keys the segmented corner/border chain"
             }

        # The wrong value pair for the type is unrepresentable, not ignored.
        # @api private
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

        # @api private
        def before_render
          raise ArgumentError, "ToggleGroup requires at least one with_item" unless items?

          return if named?

          # Lint-level warning, not an error: a radiogroup/toolbar SHOULD
          # have an accessible name.
          Rails.logger&.warn(
            "poetry ToggleGroup: nameless #{single? ? "radiogroup" : "toolbar"} - give it label: (or aria-labelledby)"
          )
        end

        # @api private
        def single?
          type != :multiple
        end

        # @api private
        def pressed_values
          @pressed_values ||= (single? ? Array(value) : Array(values)).compact.map(&:to_s)
        end

        # @api private
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
            attrs.merge(stimulus_attributes_for(:root)).merge(component_data_attributes)
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

        private :single?, :pressed_values, :root_attributes
      end
    end
  end
end
