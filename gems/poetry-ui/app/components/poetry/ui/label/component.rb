# frozen_string_literal: true

module Poetry
  module Ui
    module Label
      # The Label - always tied to a control (for_id), shadcn parity.
      class Component < Poetry::Core::Component
        AGENT_RULES = [
          "Every control gets a Label wired via for_id - placeholder text is never the label."
        ].freeze

        option :for_id, :string, required: true

        def call
          content_tag(:label, content, **root_attributes.to_attributes)
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            { "for" => for_id, "data-slot" => "label" }.merge(component_data_attributes)
          )
        end
      end
    end
  end
end
