# frozen_string_literal: true

module Poetry
  module Ui
    module DateField
      # The segmented date editor (the react-aria segment model):
      # a real native <input type=date> that IS the form value - no JS
      # means native pickers, and its value format is already the ISO wire
      # contract - progressively enhanced by poetry--core--date-field into
      # per-segment role=spinbutton editing (locale decides segment order
      # via Intl.formatToParts; arrows cycle, digits accumulate and
      # auto-advance, blur constrains February 31st). The enhanced input
      # drops out of the tab order but keeps carrying name/required/min/
      # max - native constraint validation stays on.
      class Component < Poetry::Core::Component
        # TimeField subclasses this and EXTENDS the root element with its
        # seconds/hour-cycle values - the declarations-inheritance seam.
        use_stimulus do
          on :root do
            controller :date_field do
              register
              value :locale, if: -> { locale.present? }
              value :placeholder, from: :placeholder_iso
              value :labels, from: :segment_labels_json
              value :placeholders, from: :segment_placeholders_json
            end
          end
          on :group do
            controller :date_field do
              target :group
              action :focusGap, on: :click
              action :settle, on: :focusout
            end
          end
          on :input do
            controller(:date_field) { target :input }
          end
        end

        AGENT_RULES = [
          "Date entry is a DateField (poetry_date_field / form.date_field) - never a masked " \
          "Input, three selects, or a bare input type=date when the design system is in play.",
          "The native input is the form value: params[<name>] is ISO (yyyy-mm-dd) with or " \
          "without JS; min:/max: take Date or ISO strings and ride native validation.",
          "Pair with a Label/Field for the accessible name (label for= the input id); " \
          "standalone use takes label: - segments announce it themselves.",
          "Locale drives segment order and numerals automatically; pass locale: only to pin " \
          "a field to a different locale than the page."
        ].freeze

        option :name, :string, required: true
        # Date, or an ISO yyyy-mm-dd string; nil renders empty.
        option :value, ActiveModel::Type::Value.new
        option :min, ActiveModel::Type::Value.new
        option :max, ActiveModel::Type::Value.new
        option :required, :boolean, default: false
        option :disabled, :boolean, default: false
        option :readonly, :boolean, default: false
        option :invalid, :boolean, default: false
        option :id, :string
        # Standalone accessible name (the NumberField precedent) - inside
        # a form the Field label wires ids instead.
        option :label, :string
        option :described_by, :string
        option :locale, :string
        # What the first arrow press on an empty segment lands on
        # (react-aria's placeholderValue); defaults to today.
        option :placeholder_value, ActiveModel::Type::Value.new

        part "date-field", "Root - the controller and the enhanced/disabled surface ride here",
             states: {
               "data-enhanced" => "the controller connected and built segments (no JS = the " \
                                  "native input, visible and styled)",
               "data-disabled" => "disabled: is set",
               "data-invalid" => "invalid: is set (the group wears the destructive ring)"
             }
        # The segments themselves are controller-BUILT (the FileInput list
        # precedent, so they are prose here, not parts): each editable
        # segment is span[data-slot=date-field-segment] with data-type=
        # year|month|day|hour|minute|second|dayPeriod, role=spinbutton
        # (role=textbox on iOS, where VoiceOver cannot focus spinbuttons),
        # and data-placeholder while unfilled; locale separators are
        # span[data-slot=date-field-literal] aria-hidden. Those data-slot
        # names are the restyle seam.
        part "date-field-group", "The bordered segment row (cn-input chrome, focus-within " \
                                 "ring) - hidden until enhancement, then the editing surface " \
                                 "the controller fills with segments",
             states: {
               "data-disabled" => "disabled: is set (chrome dims, pointer events off)",
               "data-invalid" => "invalid: is set (destructive border + ring)"
             }
        part "date-field-input", "The native <input type=date> - THE form value in both " \
                                 "modes; tabindex -1 + aria-hidden once segments exist"

        def control_id
          @control_id ||= id.presence || poetry_instance_id("poetry-date-field")
        end

        def root_attributes
          attrs = {
            "data-slot" => slot_prefix,
            "class" => css
          }.merge(component_data_attributes)
          attrs["data-disabled"] = "" if disabled
          attrs["data-invalid"] = "" if invalid
          html_attributes.merge_if_not_set(attrs.merge(stimulus_attributes_for(:root)))
        end

        def group_attributes
          attrs = {
            "role" => "presentation",
            "data-slot" => "#{slot_prefix}-group",
            "class" => group_classes
          }
          attrs["aria-label"] = label if label.present?
          attrs["data-invalid"] = "" if invalid
          attrs["data-disabled"] = "" if disabled
          attrs.merge(stimulus_attributes_for(:group))
        end

        def input_attributes
          attrs = Poetry::Core::HTML::Attributes.new(
            "type" => input_type,
            "name" => name,
            "id" => control_id,
            "data-slot" => "#{slot_prefix}-input",
            "class" => "#{Input::Style.css} #{css(:input)}"
          )
          attrs["value"] = iso(value) if value.present?
          attrs["min"] = iso(min) if min.present?
          attrs["max"] = iso(max) if max.present?
          attrs["aria-label"] = label if label.present?
          attrs["aria-invalid"] = "true" if invalid && !disabled
          attrs["aria-describedby"] = described_by if described_by.present?
          attrs["required"] = "" if required
          attrs["disabled"] = "" if disabled
          attrs["readonly"] = "" if readonly
          attrs.merge!(stimulus_attributes_for(:input))
          attrs
        end

        private

        def input_type
          "date"
        end

        def slot_prefix
          "date-field"
        end

        def group_classes
          css(:group)
        end

        def iso(candidate)
          candidate.respond_to?(:strftime) ? candidate.strftime("%F") : candidate.to_s
        end

        def placeholder_iso
          placeholder_value.present? ? iso(placeholder_value) : Date.current.strftime("%F")
        end

        # The AT-facing strings (segment-name fallbacks + the Empty
        # valuetext) and the visual placeholder text per segment - the
        # only translated surface; dates localize themselves via Intl.
        def segment_labels
          {
            empty: t("poetry.date_field.empty"),
            year: t("poetry.date_field.year"),
            month: t("poetry.date_field.month"),
            day: t("poetry.date_field.day"),
            hour: t("poetry.date_field.hour"),
            minute: t("poetry.date_field.minute"),
            second: t("poetry.date_field.second"),
            dayPeriod: t("poetry.date_field.day_period")
          }
        end

        def segment_placeholders
          {
            year: t("poetry.date_field.placeholder_year"),
            month: t("poetry.date_field.placeholder_month"),
            day: t("poetry.date_field.placeholder_day"),
            hour: t("poetry.date_field.placeholder_time"),
            minute: t("poetry.date_field.placeholder_time"),
            second: t("poetry.date_field.placeholder_time")
          }
        end

        def segment_labels_json = segment_labels.to_json
        def segment_placeholders_json = segment_placeholders.to_json
      end
    end
  end
end
