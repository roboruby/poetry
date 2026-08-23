# frozen_string_literal: true

module Poetry
  module Ui
    module Item
      # The Item preview: a basic row, an outline row with an icon and
      # actions, and the grouped list via the sidecar template.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component do |item|
            item.with_title { "Basic Item" }
            item.with_description { "A simple item with title and description." }
          end
        end

        def outline_with_icon_and_actions
          render_component(variant: :outline, media_variant: :icon) do |item|
            item.with_media { embed(Poetry::Ui::Icon::Component.new(name: :"badge-check")) }
            item.with_title { "Your profile has been verified." }
            item.with_actions do
              embed(Poetry::Ui::Button::Component.new(size: :sm, variant: :outline).with_content("View"))
            end
          end
        end

        # The tightest row (sm lives in the group template below).
        def size_xs
          render_component(size: :xs) do |item|
            item.with_title { "Cache cleared" }
            item.with_description { "2 minutes ago" }
          end
        end

        def group
          # An explicit per-example template (a class-level preview.html.erb
          # would shadow every other example - see Avatar's group note).
          render_with_template(template: "poetry/ui/item/group_preview")
        end
      end
    end
  end
end
