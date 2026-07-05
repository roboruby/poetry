# frozen_string_literal: true

module Poetry
  module Charts
    module PieChart
      # The polar chrome: inside labels ride fill-background (the
      # label-list block's white-on-color text); the donut center label is
      # the donut-text block's typography (text-3xl bold / muted).
      class Style < Poetry::Core::Style
        base ""

        element :frame, "contents"
        element :svg, "size-full"
        element :inside_label, "fill-background"
        element :center_title, "fill-foreground text-3xl font-bold"
        element :center_subtitle, "fill-muted-foreground"
      end
    end
  end
end
