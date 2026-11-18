# frozen_string_literal: true

module Poetry
  module Motion
    module Dock
      # The dock's classes; the swell lives in the motion stylesheet.
      class Style < Poetry::Core::Style
        base "flex w-fit items-end gap-2 rounded-2xl border bg-background/80 p-2 " \
             "data-[orientation=vertical]:flex-col data-[orientation=vertical]:items-start"
      end
    end
  end
end
