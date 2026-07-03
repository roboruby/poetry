# frozen_string_literal: true

module Poetry
  module Ui
    module Toaster
      # The toast viewport dictionary - poetry's own visual (the source
      # ships the sonner LIBRARY; poetry keeps its layout language: a
      # fixed corner column, 420px cap past mobile). pointer-events-none
      # on the region / pointer-events-auto on the items keeps the empty
      # region from swallowing clicks. The group/toaster name + the
      # data-position stamp are what the items' slide-direction selectors
      # key on.
      class Style < Poetry::Core::Style
        base "group/toaster pointer-events-none fixed z-50 flex w-full max-w-full flex-col gap-2 " \
             "p-4 sm:max-w-[420px]"

        variant :position, {
          "top-left": "top-0 left-0",
          "top-center": "top-0 left-1/2 -translate-x-1/2",
          "top-right": "top-0 right-0",
          "bottom-left": "bottom-0 left-0",
          "bottom-center": "bottom-0 left-1/2 -translate-x-1/2",
          "bottom-right": "bottom-0 right-0"
        }
      end
    end
  end
end
