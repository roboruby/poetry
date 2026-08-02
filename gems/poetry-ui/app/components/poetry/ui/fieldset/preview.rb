# frozen_string_literal: true

module Poetry
  module Ui
    module Fieldset
      # The group layer over real nested Fields - rendering rides the
      # sidecar preview.html.erb (nesting controls inside fields needs a
      # real view context, the Field preview precedent).
      class Preview < Poetry::Core::Preview::Base
        def default
          render_with(component: Component.new(legend: "Address information",
                                               hint: "We need your address to deliver the order."))
        end

        # The label-sized legend: the group is one setting explained by
        # its rows (the checkbox/switch-run form).
        def label_legend
          render_with(component: Component.new(legend: "Show these items",
                                               legend_variant: :label,
                                               hint: "Pick what lands on the desktop."))
        end
      end
    end
  end
end
