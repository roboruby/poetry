# frozen_string_literal: true

module Poetry
  module Charts
    module PieChart
      # The polar chrome on the cn-chart-* theme rules (N11): inside labels
      # ride fill-background, the donut center label keeps its 3xl type.
      class Style < Poetry::Core::Style
        base ""

        element :frame, "contents"
        element :svg, "w-full min-h-0 flex-1"
        element :inside_label, "cn-chart-inside-label"
        element :center_title, "cn-chart-center-title"
        element :center_subtitle, "cn-chart-center-subtitle"
      end
    end
  end
end
