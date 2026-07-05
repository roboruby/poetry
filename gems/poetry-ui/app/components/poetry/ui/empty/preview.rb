# frozen_string_literal: true

module Poetry
  module Ui
    module Empty
      # The Empty preview: the basic no-data state and the icon-tile
      # variant with actions.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component do |empty|
            empty.with_title { "No projects yet" }
            empty.with_description { "Get started by creating your first project." }
          end
        end

        def with_icon_and_actions
          render_component(media_variant: :icon) do |empty|
            empty.with_media { embed(Poetry::Ui::Icon::Component.new(name: :folder)) }
            empty.with_title { "No projects yet" }
            empty.with_description { "Get started by creating your first project." }
            embed(Poetry::Ui::Button::Component.new(size: :sm).with_content("Create project"))
          end
        end
      end
    end
  end
end
