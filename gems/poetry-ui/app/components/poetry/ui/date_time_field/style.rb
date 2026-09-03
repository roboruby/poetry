# frozen_string_literal: true

module Poetry
  module Ui
    module DateTimeField
      # DateField's style verbatim (one segment engine, two components) -
      # including the group/date-field marker name, which the enhanced-
      # input selector keys on. See date_field/style.rb for the rationale.
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
