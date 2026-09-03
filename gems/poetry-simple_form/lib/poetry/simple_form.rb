# frozen_string_literal: true

require "simple_form"
require "poetry/simple_form/version"
require "poetry/simple_form/inputs"

# The Poetry namespace, shared by every gem in the family.
module Poetry
  # The simple_form migration bridge: one initializer re-maps simple_form's
  # input types onto classes that render whole poetry Fields through
  # Poetry::Ui::FormBuilder. Every f.input keeps working; every poetry form
  # control is reachable by name through as:.
  module SimpleForm
    # simple_form input type => bridge input class. activate! installs
    # exactly this table, so the coverage below cannot drift from it.
    INPUTS = {
      string: Inputs::StringInput, email: Inputs::StringInput, url: Inputs::StringInput,
      tel: Inputs::StringInput, search: Inputs::StringInput, citext: Inputs::StringInput,
      uuid: Inputs::StringInput,
      password: Inputs::PasswordInput, sensitive: Inputs::SensitiveInput,
      text: Inputs::TextInput, hstore: Inputs::TextInput, json: Inputs::TextInput, jsonb: Inputs::TextInput,
      boolean: Inputs::BooleanInput, switch: Inputs::SwitchInput,
      integer: Inputs::NumericInput, decimal: Inputs::NumericInput, float: Inputs::NumericInput,
      range: Inputs::SliderInput, slider: Inputs::SliderInput,
      date: Inputs::DateTimeInput, time: Inputs::DateTimeInput, datetime: Inputs::DateTimeInput,
      date_picker: Inputs::DatePickerInput, calendar: Inputs::CalendarInput,
      file: Inputs::FileInput, otp: Inputs::OtpInput, tag_group: Inputs::TagGroupInput,
      select: Inputs::CollectionSelectInput, grouped_select: Inputs::GroupedCollectionSelectInput,
      time_zone: Inputs::TimeZoneInput, native_select: Inputs::NativeSelectInput,
      combobox: Inputs::ComboboxInput, autocomplete: Inputs::AutocompleteInput,
      radio_buttons: Inputs::CollectionRadioButtonsInput, check_boxes: Inputs::CollectionCheckBoxesInput
    }.freeze

    # simple_form input type => the poetry component it renders (a registry
    # key), or :stock where simple_form's own rendering is kept on purpose.
    # The parity gate (test/poetry/simple_form/coverage_test.rb) checks this
    # against every form-facing component in the registry.
    COVERAGE = {
      string: "input", email: "input", url: "input", tel: "input", citext: "input", uuid: "input",
      password: "input", search: "search_field", sensitive: "sensitive_input",
      text: "textarea", hstore: "textarea", json: "textarea", jsonb: "textarea",
      boolean: "checkbox", switch: "switch",
      integer: "number_field", decimal: "number_field", float: "number_field",
      range: "slider", slider: "slider",
      date: "date_field", time: "time_field", datetime: :stock,
      date_picker: "date_picker", calendar: "calendar",
      file: "file_input", otp: "input_otp", tag_group: "tag_group",
      select: "select", grouped_select: "select", time_zone: "select", native_select: "native_select",
      combobox: "combobox", autocomplete: "autocomplete",
      radio_buttons: "radio_group", check_boxes: "checkbox"
    }.freeze

    # simple_form types left to simple_form entirely, with the reason.
    STOCK = {
      datetime: "poetry has no composite date-time control yet",
      rich_text_area: "poetry ships no rich-text editor",
      hidden: "nothing to render",
      country: "the country list comes from the country_select gem, which poetry does not depend on"
    }.freeze

    # Form-facing poetry components deliberately not reachable through a
    # simple_form type, with the reason (empty today; the gate reads it).
    BRIDGE_EXEMPT = {}.freeze

    # Install the bridge: map every type in INPUTS and make the flat poetry
    # wrapper the default (the Field owns its chrome, so the wrapper
    # contributes only display: contents).
    #
    # @return [void]
    def self.activate!
      builder = ::SimpleForm::FormBuilder
      INPUTS.each { |type, klass| builder.map_type type, to: klass }

      ::SimpleForm.setup do |config|
        config.wrappers :poetry, tag: :div, class: "contents" do |b|
          b.use :input
        end
        config.default_wrapper = :poetry
      end
    end
  end
end
