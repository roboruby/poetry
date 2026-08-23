# frozen_string_literal: true

module Poetry
  module Ui
    module Skeleton
      # The Skeleton - a pulsing placeholder while content loads. Size it with
      # utility classes (h-4 w-32, size-10 rounded-full, ...); the content
      # block is optional (usually empty - the box IS the placeholder).
      #
      # @example An avatar-and-line placeholder pair
      #   render Poetry::Ui::Skeleton::Component.new(class: "size-10 rounded-full")
      #   render Poetry::Ui::Skeleton::Component.new(class: "h-4 w-32")
      class Component < Poetry::Core::Component
        AGENT_RULES = [
          "Skeleton is a loading placeholder - size it with classes (h-4 w-32); it has no content of its own.",
          "Mark the live region that will replace it (aria-busy on the container), not the skeleton."
        ].freeze

        part "skeleton", "The pulsing placeholder box itself - sized entirely by utility classes"

        def call
          content_tag(:div, content, **root_attributes.to_attributes)
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "skeleton" }.merge(component_data_attributes)
          )
        end
      end
    end
  end
end
