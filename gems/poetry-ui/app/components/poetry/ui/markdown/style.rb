# frozen_string_literal: true

module Poetry
  module Ui
    module Markdown
      # Markdown is a Typeset: the prose rules are the app-owned
      # typeset.css, so there is no theme layer here. What the dictionary
      # holds is what the component writes onto the elements it rebuilds:
      # the scroller a table sits in, and a cell's alignment.
      class Style < Poetry::Core::Style
        base "typeset"

        element :table_scroll, "typeset-scroll"

        element :align_left, "text-left"
        element :align_center, "text-center"
        element :align_right, "text-right"
      end
    end
  end
end
