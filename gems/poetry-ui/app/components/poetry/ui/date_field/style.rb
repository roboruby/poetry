# frozen_string_literal: true

module Poetry
  module Ui
    module DateField
      # Utility-only (the Separator/Spinner rule): the GROUP wears
      # cn-input's field chrome (zero new theme CSS) with a focus-within
      # ring standing in for the input's focus-visible one, since focus
      # lives on the segments inside. Segments and literals are
      # controller-BUILT, so their look rides descendant variants on the
      # group (the FileInput list idiom). The group stays hidden until the
      # controller stamps data-enhanced on the root; until then the native
      # input is the visible, styled control (no-JS = native pickers).
      class Style < Poetry::Core::Style
        base "group/date-field flex w-full flex-col"

        element :group,
                "cn-input hidden w-fit min-w-0 select-none items-center tabular-nums " \
                "group-data-[enhanced]/date-field:flex " \
                "focus-within:border-ring focus-within:ring-[3px] focus-within:ring-ring/50 " \
                "data-invalid:border-destructive data-invalid:ring-destructive/20 " \
                "dark:data-invalid:ring-destructive/40 " \
                "data-disabled:pointer-events-none data-disabled:opacity-50 " \
                "[&_[data-slot=date-field-segment]]:rounded-sm " \
                "[&_[data-slot=date-field-segment]]:px-0.5 " \
                "[&_[data-slot=date-field-segment]]:outline-none " \
                "[&_[data-slot=date-field-segment]:focus]:bg-accent " \
                "[&_[data-slot=date-field-segment]:focus]:text-accent-foreground " \
                "[&_[data-slot=date-field-segment][data-placeholder]]:text-muted-foreground " \
                "[&_[data-slot=date-field-literal]]:text-muted-foreground"
        element :input, "group-data-[enhanced]/date-field:sr-only"
      end
    end
  end
end
