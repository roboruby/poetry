# frozen_string_literal: true

module Poetry
  module Ui
    module Card
      # Re-expressed through the cn-* theme layer (N11): grid machinery
      # stays inline (upstream's split), the surface treatment + spacing
      # ride themes/default.css.
      class Style < Poetry::Core::Style
        base "cn-card flex flex-col"

        element :header, "cn-card-header grid auto-rows-min grid-rows-[auto_auto] items-start " \
                         "has-data-[slot=card-action]:grid-cols-[1fr_auto]"
        element :title, "cn-card-title"
        element :description, "cn-card-description"
        element :action, "col-start-2 row-span-2 row-start-1 self-start justify-self-end"
        element :content, "cn-card-content"
        element :footer, "cn-card-footer flex items-center [.border-t]:pt-6"
      end
    end
  end
end
