# frozen_string_literal: true

module Poetry
  module SimpleForm
    module Inputs
      # date -> DateField, time -> TimeField; :datetime falls back to
      # simple_form's stock select trio (poetry has no composite control
      # yet - a raise mid-migration would be hostile).
      class DateTimeInput < ::SimpleForm::Inputs::DateTimeInput
        # Render :date/:time attributes as poetry DateField/TimeField;
        # :datetime defers to the stock select trio via super.
        #
        # @return [String] the rendered HTML
        def input(wrapper_options = nil)
          return super if input_type == :datetime

          Poetry::Ui::FormBuilder.new(object_name, object, template, {})
                                 .input(attribute_name, as: input_type)
        end
      end
    end
  end
end
