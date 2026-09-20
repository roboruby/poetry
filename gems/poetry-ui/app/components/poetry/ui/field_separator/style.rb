# frozen_string_literal: true

module Poetry
  module Ui
    module FieldSeparator
      # Upstream FieldSeparator structure: the row is a positioning context
      # for the absolute Separator; the caption floats centered on it,
      # backed by the page background so the line breaks around the text.
      # Height/margins/type ride the theme under cn-field-separator.
      class Style < Poetry::Core::Style
        base "cn-field-separator relative"

        element :content, "cn-field-separator-content relative mx-auto block w-fit bg-background"
        # The rule the content sits on (dictionary-resident for the
        # safelist harvest).
        element :line, "absolute inset-0 top-1/2"
      end
    end
  end
end
