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

      def poetry_sheet(**, &)
        render(Poetry::Ui::Sheet::Component.new(**), &)
      end

      def poetry_alert_dialog(**, &)
        render(Poetry::Ui::AlertDialog::Component.new(**), &)
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

      def poetry_bubble(**, &)
        render(Poetry::Ui::Bubble::Component.new(**), &)
      end

      # A styled wrapper stacking one sender's consecutive bubbles - a
      # dictionary element, not a component (see Bubble).
      def poetry_bubble_group(**attrs, &)
        poetry_chat_group(Poetry::Ui::Bubble::Style, "bubble-group", **attrs, &)
      end

      def poetry_message(**, &)
        render(Poetry::Ui::Message::Component.new(**), &)
      end

      def poetry_message_group(**attrs, &)
        poetry_chat_group(Poetry::Ui::Message::Style, "message-group", **attrs, &)
      end

      def poetry_marker(**, &)
        render(Poetry::Ui::Marker::Component.new(**), &)
      end

      def poetry_attachment(**, &)
        render(Poetry::Ui::Attachment::Component.new(**), &)
      end

      # The horizontally-scrolling attachment rail (scroll-fade + snap).
      def poetry_attachment_group(**attrs, &)
        poetry_chat_group(Poetry::Ui::Attachment::Style, "attachment-group", **attrs, &)
      end

      def poetry_message_scroller(**, &)
        render(Poetry::Ui::MessageScroller::Component.new(**), &)
      end

      # One transcript row - the id is how anchoring and Turbo Streams
      # find it (data-message-id; anchor: pins the reading position).
      def poetry_message_scroller_item(id:, anchor: false, **attrs, &)
        classes = [Poetry::Ui::MessageScroller::Style.css(:item), attrs.delete(:class)].compact.join(" ")
        data = { slot: "message-scroller-item", "message-id": id }
        data[:"scroll-anchor"] = "true" if anchor
        tag.div(**attrs.merge(class: classes, data: data), &)
      end

      def poetry_collapsible(**, &)
        render(Poetry::Ui::Collapsible::Component.new(**), &)
      end

      def poetry_accordion(**, &)
        render(Poetry::Ui::Accordion::Component.new(**), &)
      end

      def poetry_dropdown_menu(**, &)
        render(Poetry::Ui::DropdownMenu::Component.new(**), &)
      end

      def poetry_context_menu(**, &)
        render(Poetry::Ui::ContextMenu::Component.new(**), &)
      end

      def poetry_menubar(**, &)
        render(Poetry::Ui::Menubar::Component.new(**), &)
      end

      private

      # The chat-set group wrappers are dictionary ELEMENTS, not components.
      def poetry_chat_group(style, slot, **attrs, &)
        classes = [style.css(slot.tr("-", "_").split("_").last.to_sym), attrs.delete(:class)].compact.join(" ")
        tag.div(**attrs.merge(class: classes, "data-slot" => slot), &)
      end
    end
  end
end
