# frozen_string_literal: true

module Poetry
  module Ui
    module Input
      class Style < Poetry::Core::Style
        base "flex h-9 w-full min-w-0 rounded-md border border-input bg-transparent px-3 py-1 " \
             "text-base shadow-xs transition-[color,box-shadow] outline-none md:text-sm " \
             "placeholder:text-muted-foreground selection:bg-primary selection:text-primary-foreground " \
             "disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50 " \
             "focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 " \
             "aria-invalid:border-destructive aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 " \
             "dark:bg-input/30"
      end
    end
  end
end
