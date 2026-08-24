# frozen_string_literal: true

require "simple_form"
require "poetry/simple_form/version"
require "poetry/simple_form/inputs"

# The poetry namespace.
module Poetry
  # The simple_form migration bridge: the
  # shim re-maps simple_form's input TYPES onto classes that render whole
  # poetry Fields through Poetry::Ui::FormBuilder, bypassing the wrapper
  # tree by design - a flat wrapper stack cannot express the Field quartet
  # (label/hint/error/aria), so the poetry Field renders it whole. Existing
  # `f.input` calls keep working; the end state is
  # form_with(builder: Poetry::Ui::FormBuilder).
  module SimpleForm
    # Idempotent: map the 80% path + install the passthrough wrapper.
    # Call from an initializer (`rails g poetry:simple_form:install`).
    #
    # @example config/initializers/poetry_simple_form.rb
    #   Poetry::SimpleForm.activate!
    # @return [void]
    def self.activate!
      builder = ::SimpleForm::FormBuilder
      builder.map_type :string, :email, :url, :tel, :search, :citext, to: Inputs::StringInput
      builder.map_type :password, to: Inputs::PasswordInput
      builder.map_type :text, to: Inputs::TextInput
      builder.map_type :boolean, to: Inputs::BooleanInput
      builder.map_type :integer, :decimal, :float, to: Inputs::NumericInput
      builder.map_type :date, :time, :datetime, to: Inputs::DateTimeInput
      builder.map_type :file, to: Inputs::FileInput
      builder.map_type :select, to: Inputs::CollectionSelectInput
      builder.map_type :radio_buttons, to: Inputs::CollectionRadioButtonsInput
      builder.map_type :check_boxes, to: Inputs::CollectionCheckBoxesInput

      ::SimpleForm.setup do |config|
        # display:contents - the wrapper div contributes nothing; the
        # poetry Field IS the field chrome. b.use :input is the whole tree.
        config.wrappers :poetry, tag: :div, class: "contents" do |b|
          b.use :input
        end
        config.default_wrapper = :poetry
      end
    end
  end
end
