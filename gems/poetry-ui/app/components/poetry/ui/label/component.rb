# frozen_string_literal: true

module Poetry
  module Ui
    module Label
      # The Label - always tied to a control (for_id), shadcn parity.
      # for_id: nil is the GROUP-label escape hatch (Field group mode): a
      # for= pointing at a role-bearing <div> is inert and Chrome flags it
      # - the group is named via aria-labelledby at this label's id instead.
      class Component < Poetry::Core::Component
        AGENT_RULES = [
          "Every control gets a Label wired via for_id - placeholder text is never the label."
        ].freeze

        option :for_id, :string

        def call
          content_tag(:label, content, **root_attributes.to_attributes)
        end

        def root_attributes
          attrs = { "data-slot" => "label" }
          attrs["for"] = for_id if for_id.present?
          html_attributes.merge_if_not_set(attrs.merge(component_data_attributes))
        end
      end
    end
  end
end
