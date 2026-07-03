# frozen_string_literal: true

module Poetry
  module Ui
    module Sheet
      class Preview < Poetry::Core::Preview::Base
        # side: :right - the detail/edit panel default.
        def default
          side_example(:right)
        end

        def left
          side_example(:left)
        end

        def top
          side_example(:top)
        end

        def bottom
          side_example(:bottom)
        end

        # The canonical Sheet recipe: an edit form beside the page context,
        # footer actions pinned to the edge by mt-auto.
        def form
          render_component(side: :right) do |sheet|
            sheet.with_trigger(variant: :outline) { "Edit profile" }
            sheet.with_title { "Edit profile" }
            sheet.with_description { "Make changes to your profile here. Click save when you're done." }
            sheet.with_footer do
              embed(Poetry::Ui::Button::Component.new(type: :submit).with_content("Save changes"))
            end
            embed(Poetry::Ui::Label::Component.new(for_id: "sheet-demo-name").with_content("Name")) +
              embed(Poetry::Ui::Input::Component.new(name: "name", value: "Pedro Duarte", id: "sheet-demo-name"))
          end
        end

        private

        def side_example(side)
          render_component(side: side) do |sheet|
            sheet.with_trigger(variant: :outline) { "Open #{side} sheet" }
            sheet.with_title { "Slide from the #{side}" }
            sheet.with_description { "A Dialog that stays visually adjacent to the page." }
            sheet.with_footer do
              embed(Poetry::Ui::Button::Component.new.with_content("Apply"))
            end
            "Sheet body content."
          end
        end
      end
    end
  end
end
