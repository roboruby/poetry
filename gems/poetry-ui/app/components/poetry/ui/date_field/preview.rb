# frozen_string_literal: true

module Poetry
  module Ui
    module DateField
      class Preview < Poetry::Core::Preview::Base
        # Empty: placeholder segments (mm/dd/yyyy under en) once enhanced;
        # the styled native input before that.
        def default
          render_component(name: "event[on]", label: "Event date")
        end

        # A server value fills the segments; the native input carries ISO.
        def with_value
          render_component(name: "invoice[due_on]", value: Date.new(2026, 3, 9), label: "Due date")
        end

        def with_range
          render_component(name: "booking[night]", label: "First night",
                           min: Date.new(2026, 1, 1), max: Date.new(2026, 12, 31))
        end

        def invalid
          render_component(name: "event[on]", label: "Event date", invalid: true,
                           value: Date.new(2020, 2, 29))
        end

        def disabled
          render_component(name: "event[on]", label: "Event date", disabled: true,
                           value: Date.new(2026, 7, 13))
        end

        # locale: pins segment order and placeholders (dd.mm.yyyy under
        # de-DE) instead of following the page locale.
        def localized
          render_component(name: "geburt[am]", label: "Geburtsdatum", locale: "de-DE",
                           value: Date.new(2026, 3, 9))
        end
      end
    end
  end
end
