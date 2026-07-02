# frozen_string_literal: true

module Poetry
  module Ui
    # The `poetry_*` view helpers - the agent-facing surface ("use
    # poetry_button, never a raw <button> with hand-written Tailwind").
    # Every registered component ships one (drift-gated by
    # ComponentsHelperTest); slot blocks receive the component:
    #
    #   <%= poetry_dialog do |dialog| %>
    #     <% dialog.with_trigger { "Open" } %>
    #     <% dialog.with_title { "Settings" } %>
    #   <% end %>
    module ComponentsHelper
      def poetry_button(**, &)
        render(Poetry::Ui::Button::Component.new(**), &)
      end

      def poetry_icon(**)
        render(Poetry::Ui::Icon::Component.new(**))
      end

      def poetry_link(**, &)
        render(Poetry::Ui::Link::Component.new(**), &)
      end

      def poetry_badge(**, &)
        render(Poetry::Ui::Badge::Component.new(**), &)
      end

      def poetry_alert(**, &)
        render(Poetry::Ui::Alert::Component.new(**), &)
      end

      def poetry_card(**, &)
        render(Poetry::Ui::Card::Component.new(**), &)
      end

      def poetry_dialog(**, &)
        render(Poetry::Ui::Dialog::Component.new(**), &)
      end

      def poetry_input(**)
        render(Poetry::Ui::Input::Component.new(**))
      end

      def poetry_label(**, &)
        render(Poetry::Ui::Label::Component.new(**), &)
      end

      def poetry_field(**, &)
        render(Poetry::Ui::Field::Component.new(**), &)
      end
    end
  end
end
