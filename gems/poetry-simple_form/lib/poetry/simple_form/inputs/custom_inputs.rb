# frozen_string_literal: true

module Poetry
  module SimpleForm
    module Inputs
      # The poetry controls with no simple_form ancestor, each reachable by
      # its poetry name: `f.input :active, as: :switch`. They are thin on
      # purpose - the Field quartet and every option ride the shared Base.

      # Serves `as: :switch`: a Field in the setting orientation wrapping the Switch.
      class SwitchInput < Base
        private

        # Renders as Poetry's switch field.
        def poetry_as = :switch
      end

      # Serves `as: :slider` and simple_form's `:range`: a Field wrapping the Slider.
      class SliderInput < Base
        private

        # Renders as Poetry's slider field.
        def poetry_as = :slider
      end

      # Serves `as: :otp`: a Field wrapping the InputOtp (length: via poetry:).
      class OtpInput < Base
        private

        # Renders as Poetry's one-time-code field.
        def poetry_as = :otp
      end

      # Serves `as: :sensitive`: a Field wrapping the masked, reveal-on-demand SensitiveInput.
      class SensitiveInput < Base
        private

        # Renders as Poetry's sensitive field.
        def poetry_as = :sensitive
      end

      # Serves `as: :tag_group`: a Field wrapping the TagGroup.
      class TagGroupInput < Base
        private

        # Renders as Poetry's tag group field.
        def poetry_as = :tag_group
      end

      # Serves `as: :date_picker`: a Field wrapping the DatePicker (popover calendar).
      class DatePickerInput < Base
        private

        # Renders as Poetry's date picker field.
        def poetry_as = :date_picker
      end

      # Serves `as: :calendar`: a Field wrapping the inline Calendar.
      class CalendarInput < Base
        private

        # Renders as Poetry's inline calendar field.
        def poetry_as = :calendar
      end
    end
  end
end
