# frozen_string_literal: true

module Poetry
  module Ui
    # The poetry FormBuilder - the model-truth end of the error
    # quartet: `form.field(:email)` renders a Field wrapping an Input with
    # everything derived from the object, never hand-wired:
    #
    #   label    from human_attribute_name (Rails i18n)
    #   value    from the object
    # error from object.errors (auto-flow)
    #   required from the model's presence validators (-> aria-required
    # only - the external generator rule; never the native attribute)
    #   ids/aria field_id + aria-describedby via Field#control_attributes
    #
    # Usage: form_with(model:, builder: Poetry::Ui::FormBuilder).
    class FormBuilder < ActionView::Helpers::FormBuilder
      include TypeInference

      # The agent surface (W3): flows into the registry's form_builder
      # section and llms.txt's Forms section.
      AGENT_RULES = [
        "Model-bound forms use form_with(model:, builder: Poetry::Ui::FormBuilder) - inside " \
        "them, ALWAYS the builder methods, never bare components (the builder derives label/" \
        "value/error/required/aria from the object).",
        "f.input(:attribute) is the default call - the type is inferred (attachment -> file, " \
        "AR enum -> select, column type, name heuristics); as: overrides it.",
        "f.association(:company) reflects the association - belongs_to renders a Combobox on " \
        "the foreign key, has_many the select-all checkbox group on singular_ids.",
        "Validations become attributes: presence -> aria-required (NEVER native required), " \
        "length -> maxlength/minlength, numericality -> min/max/step.",
        "Hints/placeholders resolve from poetry_form.* i18n (simple_form.* keys keep working " \
        "as a fallback); pass hint:/placeholder: to override.",
        "f.submit renders a poetry Button with the Rails i18n label; f.fieldset(legend:)/" \
        "f.group lay out sections; boolean f.input renders the horizontal Field " \
        "(switch: true -> the setting row)."
      ].freeze

      METHOD_SUMMARIES = {
        "input" => "the inferred entrypoint: type from as:/attachments/enums/column/name",
        "association" => "reflection-derived: belongs_to -> Combobox(fk), has_many -> checkbox group(_ids)",
        "field" => "Field-wrapped Input/Textarea (as: :textarea; orientation:/hint_position: pass through)",
        "check_box / switch" => "bare toggles (Rails check_box parity; switch = role=switch)",
        "radio_group" => "collection_radio_buttons-equivalent on RadioGroup",
        "checkbox_group" => "collection_check_boxes-equivalent on the select-all group (ONE clearing hidden)",
        "poetry_select / poetry_combobox" => "the rich pickers (Rails choice shapes; combobox multiple: chips)",
        "native_select" => "the styled native <select> (zero JS)",
        "slider / otp_field / number_field / date_field / time_field / file_input" =>
          "dedicated Field-wrapped controls",
        "search_field / sensitive_input / autocomplete / tag_group / date_picker / calendar" =>
          "the poetry-only control mappings",
        "submit / button" => "poetry Buttons (type submit; loading: opt-in)",
        "fieldset / group" => "layout frames yielding the builder"
      }.freeze

      # The registry's form_builder section (consumed by LlmsText's Forms
      # section, the MCP server, and skills - boot-free from the committed
      # registry).
      def self.registry_section
        {
          "rules" => AGENT_RULES,
          "methods" => METHOD_SUMMARIES,
          "input_types" => (INPUT_DISPATCH.keys + TYPED_FIELDS + %i[boolean enum]).map(&:to_s)
        }
      end

      # One field entrypoint for field-shaped controls: as: :input (the
      # default, with type:) or as: :textarea (rows: passes through) -
      # Own-line controls slot in as as: values; group-shaped
      # controls get dedicated methods (radio_group, slider, otp_field).
      def field(method, as: :input, hint: nil, **input_options)
        field_component = field_for(method, hint: hint,
                                            orientation: input_options.delete(:orientation),
                                            hint_position: input_options.delete(:hint_position))
        control_options = {
          name: field_name(method),
          value: object.public_send(method).presence&.to_s,
          **input_options,
          **field_component.control_attributes.transform_keys(&:to_sym)
        }
        @template.render(field_component) do
          @template.render(
            if as == :textarea
              Textarea::Component.new(**control_options)
            else
              Input::Component.new(**control_options)
            end
          )
        end
      end

      # The f.check_box-equivalent (the toggle family's form story): name/id
      # derived, checked: from the object's attribute truthiness, "1"/"0"
      # plus the unchecked-hidden pair (ActionView::Helpers::Tags::CheckBox
      # parity incl. hidden-input-first ordering - the Checkbox component
      # renders the pair). A BARE control mapping: compose with a Field
      # (control_attributes) for the label/hint/error quartet.
      def check_box(method, options = {}, checked_value = "1", unchecked_value = "0")
        @template.render Checkbox::Component.new(**toggle_options(method, options, checked_value, unchecked_value))
      end

      # The same mapping wearing switch semantics (Rails has NO native
      # switch builder): role=switch announces on/off; use it for
      # instant-effect settings, check_box for values staged for submit.
      def switch(method, options = {}, checked_value = "1", unchecked_value = "0")
        @template.render Switch::Component.new(**toggle_options(method, options, checked_value, unchecked_value))
      end

      # The collection_radio_buttons-equivalent (the exclusive-choice
      # story): a Field wrapping a RadioGroup, items from the collection
      # ([[value, label], ...] pairs or bare values), value/label/error/
      # required derived from the object. Serialization is byte-identical
      # to collection_radio_buttons (one hidden native radio per item,
      # shared name; nothing submits when none is checked).
      def radio_group(method, collection, hint: nil, **options)
        field_component = field_for(method, hint: hint, group: true)
        @template.render(field_component) do
          @template.render RadioGroup::Component.new(
            name: field_name(method),
            value: object.public_send(method).presence&.to_s,
            required: required?(method),
            invalid: field_component.invalid?,
            # The group is named by the VISIBLE Field label via
            # aria-labelledby (in group_control_attributes) - never a
            # duplicated aria-label string that can drift from it.
            **group_control_attributes(field_component),
            **options.transform_keys(&:to_sym)
          ) do |group|
            collection.each do |item|
              value, label = item.is_a?(Array) ? item : [item, item.to_s.humanize]
              group.with_item(value: value, label: label)
            end
          end
        end
      end

      # The bounded-numeric story: form.slider(:volume) single (label from
      # human_attribute_name), form.slider(:price_range, range: true,
      # label: [...]) reads an Array[2] and submits name[] (params:
      # ["200", "800"] - Rails' own array convention). Field wraps for
      # hint/error; the describedby lands on each THUMB.
      def slider(method, range: false, hint: nil, **options)
        field_component = field_for(method, hint: hint, group: true)
        value = object.public_send(method)
        slider_options = {
          name: field_name(method),
          label: options.delete(:label) || (range ? nil : field_component.label_text),
          **group_control_attributes(field_component),
          **options.transform_keys(&:to_sym)
        }
        # The thumbs carry their own names (label: - a range REQUIRES two
        # distinct ones, which a group pointer would override); the Field
        # label is visual-only here, so drop the group aria-labelledby.
        slider_options.delete(:"aria-labelledby")
        describedby = slider_options.delete(:"aria-describedby")
        slider_options[:described_by] = describedby if describedby
        if range
          slider_options[:values] = Array(value).presence ||
                                    [slider_options.fetch(:min, 0), slider_options.fetch(:max, 100)]
        else
          slider_options[:value] = value
        end
        @template.render(field_component) do
          @template.render Slider::Component.new(**slider_options)
        end
      end

      # The verification-code story: form.otp_field(:code, length: 6) - a
      # Field wrapping an InputOTP, label/error/required from the object.
      # The value is deliberately NEVER round-tripped (a rejected code is
      # dead; re-rendering it invites resubmit-the-same-wrong-code loops)
      # - pass value: explicitly to override.
      def otp_field(method, length: 6, hint: nil, **options)
        field_component = field_for(method, hint: hint)
        @template.render(field_component) do
          @template.render InputOtp::Component.new(
            name: field_name(method),
            length: length,
            required: required?(method),
            invalid: field_component.invalid?,
            **field_component.control_attributes.slice("id", "aria-describedby").transform_keys(&:to_sym),
            **options.transform_keys(&:to_sym)
          )
        end
      end

      # form.number_field(:quantity, min: 0, max: 100) - a Field wrapping
      # a NumberField, label/error/required from the object. The
      # hidden <input type=number> submits the raw value; format: only
      # shapes the display.
      def number_field(method, hint: nil, **options)
        field_component = field_for(method, hint: hint)
        describedby = field_component.control_attributes["aria-describedby"]
        @template.render(field_component) do
          @template.render NumberField::Component.new(
            name: field_name(method),
            value: object.public_send(method),
            required: required?(method),
            invalid: field_component.invalid?,
            id: field_component.control_attributes["id"],
            **(describedby ? { described_by: describedby } : {}),
            **options.transform_keys(&:to_sym)
          )
        end
      end

      # form.date_field(:due_on) - a Field wrapping a DateField;
      # params arrive as ISO yyyy-mm-dd with or without JS. OVERRIDES
      # ActionView's date_field (the number_field precedent).
      def date_field(method, hint: nil, **options)
        field_component = field_for(method, hint: hint)
        describedby = field_component.control_attributes["aria-describedby"]
        @template.render(field_component) do
          @template.render DateField::Component.new(
            name: field_name(method),
            value: object.public_send(method),
            required: required?(method),
            invalid: field_component.invalid?,
            id: field_component.control_attributes["id"],
            **(describedby ? { described_by: describedby } : {}),
            **options.transform_keys(&:to_sym)
          )
        end
      end

      # form.time_field(:starts_at) - a Field wrapping a TimeField;
      # params arrive as HH:MM (HH:MM:SS with seconds: true).
      def time_field(method, hint: nil, **options)
        field_component = field_for(method, hint: hint)
        describedby = field_component.control_attributes["aria-describedby"]
        @template.render(field_component) do
          @template.render TimeField::Component.new(
            name: field_name(method),
            value: object.public_send(method),
            required: required?(method),
            invalid: field_component.invalid?,
            id: field_component.control_attributes["id"],
            **(describedby ? { described_by: describedby } : {}),
            **options.transform_keys(&:to_sym)
          )
        end
      end

      # form.file_input(:document) / form.file_input(:photos, variant: :dropzone,
      # multiple: true) - a Field wrapping a FileInput; the native
      # input is the form value, so ActiveStorage attaches as usual.
      def file_input(method, hint: nil, **options)
        field_component = field_for(method, hint: hint)
        describedby = field_component.control_attributes["aria-describedby"]
        @template.render(field_component) do
          @template.render FileInput::Component.new(
            name: field_name(method, multiple: options[:multiple] || false),
            invalid: field_component.invalid?,
            id: field_component.control_attributes["id"],
            **(describedby ? { described_by: describedby } : {}),
            **options.transform_keys(&:to_sym)
          )
        end
      end

      # The FormBuilder#select-equivalent (the listbox capstone): a
      # Field wrapping a Select, everything derived from the object. The
      # hidden native <select> is the serialization truth (name/value/
      # required ride it), the Field's control_attributes land on the
      # TRIGGER (id + aria-describedby error-before-hint + aria-invalid),
      # and label[for: id] click-focuses the combobox.
      #
      # choices accept the Rails shapes: [["Label", value], ...] pairs,
      # flat %w[a b], grouped {"Group" => [["Label", value], ...]}, or nil
      # plus a block of select.with_item calls. include_blank: "Choose..."
      # doubles as the placeholder text (Rails include_blank semantics -
      # the blank option posts "" and fails native required validation,
      # which is the correct behavior).
      def poetry_select(method, choices = nil, include_blank: nil, hint: nil, **options, &block)
        if options.key?(:multiple)
          raise ArgumentError, "poetry_select does not support multiple: - multi-select is Combobox territory"
        end

        field_component = field_for(method, hint: hint)
        placeholder = include_blank.is_a?(String) ? include_blank : options.delete(:placeholder)
        select_options = {
          name: field_name(method),
          value: object.public_send(method).presence&.to_s,
          placeholder: placeholder,
          required: required?(method),
          **options.transform_keys(&:to_sym),
          **field_component.control_attributes.transform_keys(&:to_sym)
        }
        @template.render(field_component) do
          @template.render(Select::Component.new(**select_options)) do |select|
            populate_select_choices(select, choices) if choices
            block&.call(select)
          end
        end
      end

      # The poetry_select twin for the type-to-filter picker (the
      # combobox capstone): a Field wrapping a Combobox, everything
      # derived from the object. The hidden native <select> is the
      # serialization truth, the Field's control_attributes land on the
      # TRIGGER (id + aria-describedby error-before-hint + aria-invalid),
      # and label[for: id] click-focuses the combobox.
      #
      # choices accept the same Rails shapes as poetry_select:
      # [["Label", value], ...] pairs, flat %w[a b], grouped
      # {"Group" => [["Label", value], ...]} (group parts wear Command's
      # heading:), or nil plus a block of combobox.with_item calls.
      # include_blank: "Choose..." doubles as the placeholder text (the
      # blank option posts "" and fails native required validation -
      # deselection is a form affordance, never a re-click toggle).
      #
      # multiple: true is the chips mode: the value is the model's ARRAY
      # (params post name[] - Rails' own convention, the [] derived for
      # you) and the control_attributes land on the INLINE INPUT (the
      # chips field has no trigger); include_blank has no meaning there.
      def poetry_combobox(method, choices = nil, include_blank: nil, hint: nil, **options, &block)
        multiple = options[:multiple]
        field_component = field_for(method, hint: hint)
        placeholder = include_blank.is_a?(String) ? include_blank : options.delete(:placeholder)
        combobox_options = {
          name: field_name(method, multiple: multiple),
          value: multiple ? Array(object.public_send(method)).map(&:to_s) : object.public_send(method).presence&.to_s,
          placeholder: placeholder,
          required: required?(method),
          **options.transform_keys(&:to_sym),
          **field_component.control_attributes.transform_keys(&:to_sym)
        }
        @template.render(field_component) do
          @template.render(Combobox::Component.new(**combobox_options)) do |combobox|
            populate_combobox_choices(combobox, choices) if choices
            block&.call(combobox)
          end
        end
      end

      # -- f.input: the inferred entrypoint -----------------------------
      # form.input(:email) - one call, everything derived: type from `as:`
      # -> attachment duck-typing -> AR enum -> attribute type -> name
      # heuristics; hint/placeholder from the poetry_form (or simple_form)
      # i18n chain when not passed; maxlength/min/max from validations.
      INPUT_DISPATCH = {
        string: :field, search: :search_field, password: :password_field,
        text: :text_area, number: :number_field, date: :date_field,
        time: :time_field, file: :file_input, sensitive: :sensitive_input,
        select: :poetry_select, combobox: :poetry_combobox,
        radio_group: :radio_group, autocomplete: :autocomplete,
        tag_group: :tag_group, date_picker: :date_picker, calendar: :calendar
      }.freeze
      TYPED_FIELDS = %i[email url tel].freeze
      COLLECTION_ARGS = %i[select combobox radio_group autocomplete].freeze

      def input(method, as: nil, collection: nil, hint: nil, **options)
        type = as || infer_input_type(method, collection: collection)
        hint ||= form_i18n(:hints, method)
        options[:placeholder] = form_i18n(:placeholders, method) if options[:placeholder].nil?
        options.compact!

        return boolean_input(method, hint: hint, **options) if type == :boolean
        return enum_input(method, hint: hint, **options) if type == :enum
        if TYPED_FIELDS.include?(type)
          return field(method, hint: hint, type: type, **length_attributes(method),
                               **options)
        end

        if type == :datetime
          raise ArgumentError, "f.input cannot infer :datetime (no composite control yet) - " \
                               "pass as: :date or as: :time explicitly"
        end

        options = length_attributes(method).merge(options) if %i[string password text].include?(type)
        options = numeric_attributes(method).merge(options) if type == :number
        dispatch = INPUT_DISPATCH.fetch(type) do
          raise ArgumentError, "f.input does not know as: #{type.inspect} " \
                               "(one of #{INPUT_DISPATCH.keys.inspect}, :email, :url, :tel, :boolean, :enum)"
        end
        args = COLLECTION_ARGS.include?(type) ? [method, collection] : [method]
        send(dispatch, *args, hint: hint, **options)
      end

      # form.association(:company) - reflection-derived: belongs_to ->
      # company_id + Combobox, has_many/HABTM -> singular_ids + the
      # checkbox group; collection from the association klass, label
      # method auto-detected (to_label/name/title/to_s - simple_form's
      # chain). as: overrides (:select, :combobox, :checkbox_group).
      def association(method, as: nil, collection: nil, hint: nil, **)
        reflection = object.class.respond_to?(:reflect_on_association) &&
                     object.class.reflect_on_association(method)
        raise ArgumentError, "no association #{method.inspect} on #{object.class}" unless reflection
        if reflection.macro == :has_one
          raise ArgumentError, "has_one associations have no form control (build the record and use fields_for)"
        end

        collection ||= reflection.klass.all
        pairs = collection.map { |item| [association_label(item), item.id] }

        if reflection.macro == :belongs_to
          attribute = association_attribute(reflection, method)
          # radio_group items read [value, label] - the inverse of the
          # select/combobox [label, value] pairs.
          if as == :radio_group
            radio_group(attribute, pairs.map { |label, value| [value, label] }, hint: hint, **)
          else
            send(INPUT_DISPATCH.fetch(as || :combobox), attribute, pairs, hint: hint, **)
          end
        else
          collection_association(method, pairs, as, hint: hint, **)
        end
      end

      # -- Rails-parity typed inputs ------------------------------------
      # The stock helper names answer with poetry Fields: text_field ->
      # field(type: :text) etc. password_field NEVER round-trips the value
      # (Rails' own behavior); revealable SECRETS (API keys) are
      # sensitive_input, login passwords stay type=password here.
      { text_field: :text, email_field: :email, url_field: :url,
        telephone_field: :tel }.each do |helper, type|
        define_method(helper) do |method, hint: nil, **options|
          field(method, hint: hint, type: type, **options)
        end
      end
      alias phone_field telephone_field

      def password_field(method, hint: nil, **)
        field(method, hint: hint, type: :password, value: nil, **)
      end

      def text_area(method, hint: nil, **)
        field(method, as: :textarea, hint: hint, **)
      end

      # form.search_field(:query) - a Field wrapping the SearchField
      # (native type=search + the clear affordance).
      def search_field(method, hint: nil, **options)
        field_component = field_for(method, hint: hint)
        describedby = field_component.control_attributes["aria-describedby"]
        @template.render(field_component) do
          @template.render SearchField::Component.new(
            name: field_name(method),
            value: object.public_send(method).presence&.to_s,
            id: field_component.control_attributes["id"],
            **(describedby ? { described_by: describedby } : {}),
            **options.transform_keys(&:to_sym)
          )
        end
      end

      # form.sensitive_input(:api_key) - the revealable-secret story
      #: masked at rest, reveal + optional copy:.
      def sensitive_input(method, hint: nil, **options)
        field_component = field_for(method, hint: hint)
        describedby = field_component.control_attributes["aria-describedby"]
        @template.render(field_component) do
          @template.render SensitiveInput::Component.new(
            name: field_name(method),
            value: object.public_send(method).presence&.to_s,
            id: field_component.control_attributes["id"],
            **(describedby ? { described_by: describedby } : {}),
            **options.transform_keys(&:to_sym)
          )
        end
      end

      # form.autocomplete(:city, %w[...]) - the input IS the value
      # (suggestions are conveniences, not constraints); items from the
      # suggestions array ([label, value] pairs or bare strings) or a
      # block of auto.with_item calls.
      def autocomplete(method, suggestions = nil, hint: nil, **options, &block)
        field_component = field_for(method, hint: hint)
        control = {
          name: field_name(method),
          value: object.public_send(method).presence&.to_s,
          **options.transform_keys(&:to_sym),
          **field_component.control_attributes.transform_keys(&:to_sym)
        }
        @template.render(field_component) do
          @template.render(Autocomplete::Component.new(**control)) do |auto|
            Array(suggestions).each do |choice|
              label, value = choice.is_a?(Array) ? choice : [choice.to_s, nil]
              auto.with_item(label: label, **(value ? { value: value } : {}))
            end
            block&.call(auto)
          end
        end
      end

      # form.native_select(:country, [["USA", "us"], ...]) - the styled
      # NATIVE <select> (zero JS); poetry_select/poetry_combobox stay the
      # rich paths. include_blank: posts "" (Rails semantics).
      def native_select(method, choices = nil, include_blank: nil, hint: nil, **options)
        field_component = field_for(method, hint: hint)
        pairs = Array(choices).map { |c| c.is_a?(Array) ? c : [c.to_s, c] }
        pairs.unshift([include_blank.is_a?(String) ? include_blank : "", ""]) if include_blank
        describedby = field_component.control_attributes["aria-describedby"]
        @template.render(field_component) do
          @template.render NativeSelect::Component.new(
            name: field_name(method),
            options: pairs,
            selected: object.public_send(method).presence&.to_s,
            invalid: field_component.invalid?,
            id: field_component.control_attributes["id"],
            **(describedby ? { "aria-describedby": describedby } : {}),
            **options.transform_keys(&:to_sym)
          )
        end
      end

      # form.tag_group(:topics) - the removable-chips story for an ARRAY
      # attribute: one hidden name[] per tag, plus the leading empty
      # hidden (Rails array convention: removing every tag still clears).
      def tag_group(method, hint: nil, **options)
        field_component = field_for(method, hint: hint, group: true)
        values = Array(object.public_send(method)).map(&:to_s)
        @template.hidden_field_tag(field_name(method, multiple: true), "", id: nil) +
          @template.render(field_component) do
            @template.render(TagGroup::Component.new(
                               name: field_name(method),
                               label: field_component.label_text,
                               **group_control_attributes(field_component).except(:"aria-labelledby"),
                               **options.transform_keys(&:to_sym)
                             )) do |group|
              values.each { |value| group.with_tag(value: value, text: value) }
            end
          end
      end

      # The collection_check_boxes-equivalent: a Field(group) wrapping the
      # APG select-all group (DD sweep) - items post name[] and the
      # leading empty hidden clears when none are checked. select_all:
      # true (or a label string) adds the mixed-state parent checkbox.
      def checkbox_group(method, collection, hint: nil, select_all: false, **options)
        field_component = field_for(method, hint: hint, group: true)
        chosen = Array(object.public_send(method)).map(&:to_s)
        base_id = field_id(method)
        @template.hidden_field_tag(field_name(method, multiple: true), "", id: nil) +
          @template.render(field_component) do
            @template.poetry_checkbox_group(
              class: "flex flex-col gap-2",
              **group_control_attributes(field_component).slice(:id, :"aria-labelledby"),
              **options.transform_keys(&:to_sym)
            ) do
              rows = []
              rows << checkbox_group_all_row(base_id, select_all) if select_all
              rows.concat(checkbox_group_item_rows(method, collection, chosen, base_id))
              @template.safe_join(rows)
            end
          end
      end

      # form.date_picker(:due_on) - the calendar-popup pick; value posts
      # ISO like date_field. (Quartet ids land on the composed control's
      # root for now - the input-level aria refinement comes later.)
      def date_picker(method, hint: nil, **options)
        field_component = field_for(method, hint: hint, group: true)
        @template.render(field_component) do
          @template.render DatePicker::Component.new(
            name: field_name(method),
            value: object.public_send(method).presence&.to_s,
            **group_control_attributes(field_component).slice(:id, :"aria-describedby"),
            **options.transform_keys(&:to_sym)
          )
        end
      end

      # form.calendar(:starts_on) - the always-visible month grid as a
      # form participant (mode: :range posts name[]).
      def calendar(method, hint: nil, **options)
        field_component = field_for(method, hint: hint, group: true)
        value = object.public_send(method)
        @template.render(field_component) do
          @template.render Calendar::Component.new(
            name: field_name(method),
            value: value.is_a?(Array) ? value.map(&:to_s) : value.presence&.to_s,
            **group_control_attributes(field_component).slice(:id, :"aria-describedby"),
            **options.transform_keys(&:to_sym)
          )
        end
      end

      # -- Rails-arity adapters -----------------------------------------

      # ActionView's select arity adapted onto poetry_select.
      def select(method, choices = nil, options = {}, html_options = {}, &)
        poetry_select(method, choices,
                      include_blank: options[:include_blank] || options[:prompt],
                      **html_options.transform_keys(&:to_sym), &)
      end

      # rubocop:disable Metrics/ParameterLists -- the ActionView arity, verbatim
      def collection_select(method, collection, value_method, text_method, options = {}, html_options = {})
        pairs = collection.map { |item| [item.public_send(text_method), item.public_send(value_method)] }
        poetry_select(method, pairs,
                      include_blank: options[:include_blank] || options[:prompt],
                      **html_options.transform_keys(&:to_sym))
      end
      # rubocop:enable Metrics/ParameterLists

      def collection_radio_buttons(method, collection, value_method, text_method, **)
        pairs = collection.map { |item| [item.public_send(value_method), item.public_send(text_method)] }
        radio_group(method, pairs, **)
      end

      def collection_check_boxes(method, collection, value_method, text_method, **)
        pairs = collection.map { |item| [item.public_send(value_method), item.public_send(text_method)] }
        checkbox_group(method, pairs, **)
      end

      # -- Actions ------------------------------------------------------

      # form.submit -> a poetry Button (type submit); label from Rails'
      # own i18n default ("Create Model" / "Update Model"). loading: true
      # opts into the Button loading treatment.
      def submit(value = nil, **options)
        value ||= submit_default_value
        @template.render(Button::Component.new(type: :submit, **options.transform_keys(&:to_sym))) { value }
      end

      def button(value = nil, **options, &block)
        content = block ? @template.capture(&block) : value || submit_default_value
        @template.render(Button::Component.new(type: :submit, **options.transform_keys(&:to_sym))) { content }
      end

      # -- Layout -------------------------------------------------------

      # form.fieldset(legend: "Shipping") { |f| ... } - the grouped-fields
      # frame; yields the builder for nesting.
      def fieldset(legend:, hint: nil, **options, &block)
        @template.render(Fieldset::Component.new(legend: legend, hint: hint,
                                                 **options.transform_keys(&:to_sym))) do
          @template.capture(self, &block)
        end
      end

      # form.group { |f| ... } - the FieldGroup stack (the @container the
      # responsive Field orientation measures against).
      def group(**options, &block)
        @template.render(FieldGroup::Component.new(**options.transform_keys(&:to_sym))) do
          @template.capture(self, &block)
        end
      end

      private

      # Rails choice shapes -> Select parts: a Hash groups (label part per
      # key), arrays are ["Label", value] pairs (options_for_select-exact)
      # or bare values (value doubles as the label).
      def populate_select_choices(owner, choices)
        if choices.is_a?(Hash)
          choices.each do |group_label, group_choices|
            owner.with_group(label: group_label.to_s) do |group|
              group_choices.each { |choice| add_select_item(group, choice) }
            end
          end
        else
          choices.each { |choice| add_select_item(owner, choice) }
        end
      end

      def add_select_item(owner, choice)
        label, value = choice.is_a?(Array) ? choice : [choice.to_s, choice]
        owner.with_item(value: value.to_s) { label.to_s }
      end

      # The same Rails shapes onto Combobox parts - groups wear the
      # embedded Command's heading: (vs Select's label:).
      def populate_combobox_choices(owner, choices)
        if choices.is_a?(Hash)
          choices.each do |group_heading, group_choices|
            owner.with_group(heading: group_heading.to_s) do |group|
              group_choices.each { |choice| add_select_item(group, choice) }
            end
          end
        else
          choices.each { |choice| add_select_item(owner, choice) }
        end
      end

      # Group-shaped controls take the id (item ids derive from it) and
      # the describedby wiring from the Field; invalid/required ride the
      # component's own options (aria-invalid belongs on the ITEMS, not
      # the root).
      def group_control_attributes(field_component)
        field_component.control_attributes
                       .slice("id", "aria-describedby", "aria-labelledby")
                       .transform_keys(&:to_sym)
      end

      def field_for(method, hint: nil, group: false, orientation: nil, hint_position: nil)
        extras = { orientation: orientation, hint_position: hint_position }.compact
        Field::Component.new(
          id: field_id(method),
          label_text: object.class.human_attribute_name(method),
          hint: hint,
          error: error_for(method),
          required: required?(method),
          group: group,
          **extras
        )
      end

      # Shared derivation for the toggle-family builder methods: everything
      # from the object, never hand-wired. required maps to aria-required
      # only (the lock - the components never render native required).
      def toggle_options(method, options, checked_value, unchecked_value)
        {
          name: field_name(method),
          id: field_id(method),
          checked: ActiveModel::Type::Boolean.new.cast(object.public_send(method)) || false,
          value: checked_value,
          unchecked_value: unchecked_value,
          required: required?(method),
          **options.transform_keys(&:to_sym)
        }
      end

      # f.input's boolean story: the horizontal boolean-control layout
      # (checkbox on the label line); switch: true renders the setting row
      # (label + hint left, switch right).
      def boolean_input(method, hint: nil, switch: false, **options)
        orientation = switch ? :setting : :horizontal
        field_component = field_for(method, hint: hint, orientation: orientation)
        control = toggle_options(method, options, "1", "0")
                  .merge(field_component.control_attributes.transform_keys(&:to_sym))
        @template.render(field_component) do
          @template.render((switch ? Switch::Component : Checkbox::Component).new(**control))
        end
      end

      # AR enums: humanized keys as a select (as: :radio_group lays a
      # small set flat).
      def enum_input(method, hint: nil, **)
        pairs = object.class.defined_enums.fetch(method.to_s).keys.map { |key| [key.humanize, key] }
        poetry_select(method, pairs, hint: hint, **)
      end

      def association_label(item)
        %i[to_label name title].each do |candidate|
          return item.public_send(candidate) if item.respond_to?(candidate)
        end
        item.to_s
      end

      def association_attribute(reflection, method)
        attribute = (reflection.respond_to?(:foreign_key) && reflection.foreign_key) || "#{method}_id"
        attribute.to_sym
      end

      def collection_association(method, pairs, as, hint: nil, **)
        attribute = :"#{method.to_s.singularize}_ids"
        case as
        when :combobox
          poetry_combobox(attribute, pairs, hint: hint, multiple: true, **)
        when :select, :radio_group
          raise ArgumentError, "collection associations need a multi-value control (:checkbox_group or :combobox)"
        else
          checkbox_group(attribute, pairs.map { |label, value| [value, label] }, hint: hint, **)
        end
      end

      # The checkbox-group rows (extracted for the coverage the builder
      # method reads better without).
      def checkbox_group_all_row(base_id, select_all)
        all_id = "#{base_id}_all"
        @template.content_tag(:div, class: "flex items-center gap-2") do
          @template.poetry_checkbox_group_all(id: all_id) +
            @template.poetry_label(for_id: all_id) do
              select_all.is_a?(String) ? select_all : "All"
            end
        end
      end

      def checkbox_group_item_rows(method, collection, chosen, base_id)
        collection.map do |item|
          value, label = item.is_a?(Array) ? item : [item, item.to_s.humanize]
          item_id = "#{base_id}_#{value.to_s.parameterize(separator: "_")}"
          @template.content_tag(:div, class: "flex items-center gap-2") do
            @template.poetry_checkbox_group_item(
              name: field_name(method, multiple: true), value: value.to_s,
              checked: chosen.include?(value.to_s), unchecked_value: nil, id: item_id
            ) + @template.poetry_label(for_id: item_id) { label.to_s }
          end
        end
      end

      # The vcf dual-key recipe: company_id also reads errors on :company
      # (validates :company, presence: true is the Rails idiom, but the
      # form field is the _id attribute).
      def error_for(method)
        return nil unless object.respond_to?(:errors)

        message = object.errors.full_messages_for(method).first
        if message.nil? && (base = method.to_s[/\A(.+?)_ids?\z/, 1])
          message = object.errors.full_messages_for(base.to_sym).first ||
                    object.errors.full_messages_for(base.pluralize.to_sym).first
        end
        message
      end

      # Presence -> required, with the vcf filtering recipe: conditional
      # validators (:if/:unless) never claim required, and :on contexts
      # must match the record's persistence.
      def required?(method)
        return false unless object.class.respond_to?(:validators_on)

        context = object.respond_to?(:persisted?) && object.persisted? ? :update : :create
        object.class.validators_on(method).any? do |validator|
          next false unless validator.kind == :presence
          next false if validator.options[:if] || validator.options[:unless]

          on = Array(validator.options[:on])
          on.empty? || on.include?(context)
        end
      end

      # The Rails 8 respellings (the vcf coverage lesson): ActionView 8
      # aliases textarea/checkbox at ITS class body, so a subclass override
      # of the old name never reaches them - define both, version-gated.
      if ActionView::VERSION::MAJOR >= 8

        public

        def textarea(method, hint: nil, **) = text_area(method, hint: hint, **)

        def checkbox(method, options = {}, checked_value = "1", unchecked_value = "0")
          check_box(method, options, checked_value, unchecked_value)
        end

        def collection_checkboxes(method, collection, value_method, text_method, **)
          collection_check_boxes(method, collection, value_method, text_method, **)
        end
      end
    end
  end
end
