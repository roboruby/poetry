# frozen_string_literal: true

module Poetry
  module SimpleForm
    module Inputs
      # date -> DateField, time -> TimeField; :datetime falls back to
      # poetry's own DateTimeField (one datetime-local control, no select trio).
      class DateTimeInput < ::SimpleForm::Inputs::DateTimeInput
        # Render :date/:time/:datetime attributes as poetry DateField /
        # TimeField / DateTimeField - one control each, ISO on the wire.
        #
        # @param _wrapper_options [Hash, nil] Simple Form's wrapper options, unused: the Field is the wrapper
        # @return [String] the rendered HTML
        def input(_wrapper_options = nil)
          Poetry::Ui::FormBuilder.new(object_name, object, template, {})
                                 .input(attribute_name, as: input_type)
        end
      end
    end
  end
end
