# frozen_string_literal: true

module Poetry
  module Ui
    module ButtonGroup
      # The ButtonGroup preview: a segmented pair, a prefix text member,
      # and the vertical orientation.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component("aria-label": "Text alignment") do
            embed(button("Left", variant: :outline)) +
              embed(button("Center", variant: :outline)) +
              embed(button("Right", variant: :outline))
          end
        end

        def with_text_prefix
          # Part helpers need a real view context - a per-example template
          # (a class-level preview.html.erb would hijack every example).
          render_with_template(template: "poetry/ui/button_group/text_prefix_preview")
        end

        def vertical
          render_component(orientation: :vertical, "aria-label": "Vertical actions") do
            embed(button("Top", variant: :outline)) +
              embed(button("Bottom", variant: :outline))
          end
        end

        # The corner rig for popup wrappers (select / dropdown-menu /
        # popover render a Stimulus wrapper around their trigger, unlike
        # upstream fragments): first, middle, and last positions each
        # prove the theme chains reach the trigger THROUGH its wrapper.
        def popup_triggers
          render_with_template(template: "poetry/ui/button_group/popup_triggers_preview")
        end

        private

        def button(text, **)
          Poetry::Ui::Button::Component.new(**).with_content(text)
        end
      end
    end
  end
end
