# frozen_string_literal: true

module Poetry
  module Ui
    module RadioGroup
      # First of the forms family (RadioGroup) - the
      # first roving-focus consumer with SELECTION semantics. Two machines
      # compose on one root (the Accordion/ToggleGroup shape): the thin
      # poetry--core--radio-group checked-value machine (zero keyboard
      # code) and poetry--core--roving-focus in its DEFAULT tabindex-
      # managing mode with orientation "both" (APG radio: all four arrows,
      # horizontal pair RTL-flipped). Selection follows focus by consuming
      # roving-focus's cancelable entry event - it fires only on
      # arrow/Home/End navigation, never on Tab, so Tab into the group can
      # never change the value (Radix-exact).
      #
      # The form story is the hidden-native-input rule: one hidden
      # <input type=radio> PER item, shared name (aria-hidden, tabindex=-1)
      # - native radio serialization, byte-identical to
      # collection_radio_buttons (checked value only; NOTHING submits when
      # none is checked, so presence validation stays honest). The server
      # renders the roving tab stop (checked item tabindex=0, rest -1) so
      # the one-Tab-stop contract holds before JS connects.
      class Component < Poetry::Core::Component
        GROUP = %i[poetry core radio_group].freeze
        ROVING = %i[poetry core roving_focus].freeze
        ORIENTATIONS = %i[both vertical horizontal].freeze

        AGENT_RULES = [
          "Use poetry_radio_group / form.radio_group - never hand-roll role=radio buttons.",
          "Every item MUST have a unique value: (ArgumentError on duplicates).",
          "The GROUP must be labelled - label: (or aria-labelledby) - an unlabelled radiogroup is an " \
          "APG violation (ArgumentError).",
          "Pair every item with a visible label (item label: renders the Label for= pairing) - a bare " \
          "dot is not an option.",
          "NEVER write the checked attributes (data-checked/data-unchecked) without aria-checked (the " \
          "controller writes both; agents patching DOM must too).",
          "Do not use RadioGroup for navigation or immediate actions; checking must not submit or " \
          "navigate by itself.",
          "7+ options: use Select instead.",
          "Wire errors through Field/FormBuilder (invalid: + describedby on the root) - never a bare " \
          "red ring."
        ].freeze

        # The shared form name for every hidden radio (FormBuilder derives
        # object[method]).
        option :name, :string, required: true
        # The checked item's value; nil = nothing checked (pre-selection).
        option :value, :string
        # aria-required on the ROOT only - never native required on the
        # hidden inputs (constraint-validation focus would land on an
        # aria-hidden input; the/Field rule).
        option :required, :boolean, default: false
        # Disables every item (root-level).
        option :disabled, :boolean, default: false
        # Arrow wrap at the ends (Radix default true).
        option :loop, :boolean, default: true
        # Keyboard axis. APG radio = all four arrows (:both, the default +
        # Radix parity); :vertical/:horizontal restrict the axis. NO visual
        # effect (source has none).
        option :orientation, :symbol, default: :both
        # aria-invalid on the items (the destructive ring) - set by
        # Field/FormBuilder from model errors.
        option :invalid, :boolean, default: false
        # The group accessible name -> aria-label (or wire aria-labelledby
        # yourself) - REQUIRED: an unlabelled radiogroup fails the audit.
        option :label, :string

        validates :orientation, inclusion: { in: ORIENTATIONS }

        # One item per option: a real button[role=radio] carrying its own
        # hidden native radio; label: renders the demo's item+Label row.
        renders_many :items, lambda { |value:, label: nil, id: nil, disabled: false, **options|
          item_value = register_item_value!(value)
          item_id = id.presence || "#{control_id}-#{slug(item_value)}"
          item_disabled = disabled || self.disabled
          item = radio_item(item_value, item_id, item_disabled, options)

          next item if label.blank?

          # Source parity (radio-group-demo): the item + Label pairing row.
          # The for= targets the BUTTON id - label clicks check via the
          # controller (native label->button activation).
          content_tag(:div, class: css(:row)) do
            safe_join([item, render(Label::Component.new(for_id: item_id).with_content(label))])
          end
        }

        def before_render
          raise ArgumentError, "RadioGroup requires at least one with_item" unless items?

          return if named?

          raise ArgumentError,
                "unlabelled RadioGroup - give it label: (or aria-labelledby); a radiogroup without an " \
                "accessible name is an APG violation"
        end

        def checked?(item_value)
          value.present? && value.to_s == item_value
        end

        # The label-for/aria target root id - server-stable (Field-issued
        # or auto) so item ids derive deterministically.
        def control_id
          @control_id ||= html_attributes["id"].presence || "poetry-radio-group-#{SecureRandom.hex(4)}"
        end

        def root_attributes
          attrs = {
            "role" => "radiogroup", "data-slot" => "radio-group", "id" => control_id
          }
          attrs["aria-required"] = true if required
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
            raise ArgumentError, "duplicate RadioGroup item value #{item_value.inspect} - values key " \
                                 "the checked-value machine"
          end

          item_value
        end

        # No raw user string becomes an id/selector fragment.
        def slug(value)
          value.gsub(/[^a-zA-Z0-9_-]+/, "-")
        end

        def named?
          aria = html_attributes["aria"] || {}
          label.present? ||
            html_attributes["aria-label"].present? || html_attributes["aria-labelledby"].present? ||
            aria["label"].present? || aria["labelledby"].present?
        end

        def radio_item(item_value, item_id, item_disabled, options)
          checked = checked?(item_value)

          attrs = {
            type: "button", role: "radio", id: item_id, class: item_classes(options.delete(:class)),
            "data-slot" => "radio-group-item", "data-poetry-collection-item" => "",
            "data-value" => item_value,
            "aria-checked" => checked.to_s, (checked ? "data-checked" : "data-unchecked") => "",
            "tabindex" => tab_stop?(item_value, item_disabled) ? "0" : "-1"
          }
          attrs["aria-invalid"] = "true" if invalid
          if item_disabled
            attrs[:disabled] = true
            attrs["data-disabled"] = "" # the roving-focus collection filter
          end
          attrs.merge!(stimulus_attributes(GROUP) { |group| group.with_action(:check, on: :click) })

          # The native input is the button's SIBLING - a focusable native
          # control inside a role=radio button is axe nested-interactive
          # (caught by the a11y rig, 2026-07-03).
          safe_join([
                      content_tag(:button, attrs.merge(options)) { indicator(checked) },
                      hidden_radio(item_value, item_id, checked, item_disabled)
                    ])
        end

        def indicator(checked)
          attrs = { class: css(:indicator), "data-slot" => "radio-group-indicator" }
          # A hidden attr toggle, not presence - shadcn renders no check
          # animation (source-exact, morph-safe).
          attrs[:hidden] = true unless checked
          content_tag(:span, render(Icon::Component.new(name: :circle, class: css(:dot))), attrs)
        end

        # THE form participant: native radio serialization (same form+name
        # group), aria-hidden + tabindex=-1 (the role=radio button is the
        # focusable/AT surface - render tests pin the no-double-Tab-stop
        # invariant).
        def hidden_radio(item_value, item_id, checked, item_disabled)
          tag.input(type: "radio", name: name, value: item_value, id: "#{item_id}-input",
                    checked: checked, disabled: item_disabled, "aria-hidden": true,
                    tabindex: "-1", class: css(:input),
                    "data-poetry--core--radio-group-target": "input")
        end

        # The server renders the roving contract: exactly one tabindex=0 -
        # the checked item, else the FIRST enabled item (Tab lands there
        # when nothing is checked). Sequential across item registration.
        def tab_stop?(item_value, item_disabled)
          return false if @tab_stop_assigned || item_disabled

          stop = value.present? ? checked?(item_value) : true
          @tab_stop_assigned = true if stop
          stop
        end

        def item_classes(extra)
          classnames(css(:item), extra)
        end

        # BOTH controllers build into ONE Attributes instance (the
        # Accordion lesson: a plain Hash#merge would overwrite
        # data-controller instead of token-concatenating).
        def root_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          group = Poetry::Core::Stimulus::Builder.new(GROUP, attrs)
          group.register_controller
          group.with_value(:value, value.to_s) if value.present?
          # Selection follows focus: entry fires ONLY on arrow/Home/End
          # navigation (never Tab), so checking on entry IS the APG radio
          # contract.
          group.with_action(:entry_check, on: "poetry--core--roving-focus:entry")
          roving = Poetry::Core::Stimulus::Builder.new(ROVING, attrs)
          roving.register_controller
          # DEFAULT tabindex-managing mode: the group is ONE Tab stop.
          roving.with_value(:orientation, orientation)
          roving.with_value(:loop, loop)
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
