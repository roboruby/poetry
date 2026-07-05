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

      # The Table (N8): the component renders the overflow container + real
      # `<table>`; the part helpers stamp the data-slot + source-exact classes
      # onto the semantic table elements the consumer composes.
      def poetry_table(**, &)
        render(Poetry::Ui::Table::Component.new(**), &)
      end

      {
        table_header: [:thead, "table-header", :header],
        table_body: [:tbody, "table-body", :body],
        table_footer: [:tfoot, "table-footer", :footer],
        table_row: [:tr, "table-row", :row],
        table_head: [:th, "table-head", :head],
        table_cell: [:td, "table-cell", :cell],
        table_caption: [:caption, "table-caption", :caption]
      }.each do |name, (tag_name, slot, element)|
        define_method("poetry_#{name}") do |**attrs, &block|
          classes = [Poetry::Ui::Table::Style.css(element), attrs.delete(:class)].compact.join(" ")
          data = { slot: slot }.merge(attrs.delete(:data) || {})
          content_tag(tag_name, (capture(&block) if block), **attrs, class: classes, data: data)
        end
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

      # Input's multiline sibling - the value is the CONTENT (value:), not
      # a block; auto-grow is CSS (field-sizing-content), never a JS
      # autosizer.
      def poetry_textarea(**)
        render(Poetry::Ui::Textarea::Component.new(**))
      end

      # Fixed-length code entry: ONE native input over aria-hidden cells
      # (paste/SMS-autofill/IME all native) - never per-cell inputs.
      def poetry_input_otp(**)
        render(Poetry::Ui::InputOtp::Component.new(**))
      end

      def poetry_label(**, &)
        render(Poetry::Ui::Label::Component.new(**), &)
      end

      def poetry_field(**, &)
        render(Poetry::Ui::Field::Component.new(**), &)
      end

      # Void control (no content block) - the label is EXTERNAL (Label/Field
      # for= the button id) or label: (the aria-label fallback).
      def poetry_checkbox(**)
        render(Poetry::Ui::Checkbox::Component.new(**))
      end

      # Void control - instant-effect on/off (role=switch announces on/off);
      # values staged for submit belong to poetry_checkbox.
      def poetry_switch(**)
        render(Poetry::Ui::Switch::Component.new(**))
      end

      # The exclusive-choice control: group.with_item(value:, label:) -
      # one hidden native radio per item (collection_radio_buttons-exact
      # serialization). The group MUST be labelled (label: or
      # aria-labelledby).
      def poetry_radio_group(**, &)
        render(Poetry::Ui::RadioGroup::Component.new(**), &)
      end

      # Void control - numeric value (value:) or [low, high] range
      # (values:) on a continuous track; every thumb needs a distinct
      # accessible name (label:).
      def poetry_slider(**)
        render(Poetry::Ui::Slider::Component.new(**))
      end

      def poetry_bubble(**, &)
        render(Poetry::Ui::Bubble::Component.new(**), &)
      end

      # A styled wrapper stacking one sender's consecutive bubbles - a
      # dictionary element, not a component (see Bubble).
      def poetry_bubble_group(**attrs, &)
        poetry_chat_group(Poetry::Ui::Bubble::Style, "bubble-group", **attrs, &)
      end

      # Pressed-state button (aria-pressed) - UI state, NOT form data; the
      # content block is the icon/text (icon-only requires label:).
      def poetry_toggle(**, &)
        render(Poetry::Ui::Toggle::Component.new(**), &)
      end

      # A set of Toggle-styled items under one value machine + one roving
      # tab stop: group.with_item(value:, label:) { icon/text }.
      def poetry_toggle_group(**, &)
        render(Poetry::Ui::ToggleGroup::Component.new(**), &)
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

      def poetry_toast(**, &)
        render(Poetry::Ui::Toast::Component.new(**), &)
      end

      # The toast viewport - render ONCE in the application layout (it is
      # data-turbo-permanent; turbo_stream.poetry_toast appends into it).
      def poetry_toaster(**, &)
        render(Poetry::Ui::Toaster::Component.new(**), &)
      end

      def poetry_collapsible(**, &)
        render(Poetry::Ui::Collapsible::Component.new(**), &)
      end

      def poetry_accordion(**, &)
        render(Poetry::Ui::Accordion::Component.new(**), &)
      end

      def poetry_popover(**, &)
        render(Poetry::Ui::Popover::Component.new(**), &)
      end

      def poetry_tooltip(**, &)
        render(Poetry::Ui::Tooltip::Component.new(**), &)
      end

      # The tooltip delay/warm SCOPE - a config-carrying div, NOT a
      # controller (the DOM ancestor IS Radix's React context; the tooltip
      # controller reads closest('[data-slot=tooltip-provider]') and keys
      # the module-level warm registry by it). Wrap control rows in ONE
      # provider so the warm grace makes the row feel continuous.
      def poetry_tooltip_provider(delay_duration: 0, skip_delay_duration: 300,
                                  disable_hoverable_content: false, **attrs, &)
        data = (attrs.delete(:data) || {}).merge(
          slot: "tooltip-provider",
          delay_duration: delay_duration,
          skip_delay_duration: skip_delay_duration,
          disable_hoverable_content: disable_hoverable_content
        )
        tag.div(**attrs, data: data, &)
      end

      def poetry_hover_card(**, &)
        render(Poetry::Ui::HoverCard::Component.new(**), &)
      end

      def poetry_dropdown_menu(**, &)
        render(Poetry::Ui::DropdownMenu::Component.new(**), &)
      end

      # The value-choosing listbox (options ARE values; actions belong to
      # poetry_dropdown_menu). Must be named: a Field label (id: +
      # label[for]) or aria-label. In forms, prefer f.poetry_select.
      def poetry_select(**, &)
        render(Poetry::Ui::Select::Component.new(**), &)
      end

      # The type-to-filter value picker (Select's shell x Command's
      # engine): options ARE values, committed to a hidden native select.
      # Must be named (Field label via id: or aria-label). In forms,
      # prefer f.poetry_combobox.
      def poetry_combobox(**, &)
        render(Poetry::Ui::Combobox::Component.new(**), &)
      end

      def poetry_context_menu(**, &)
        render(Poetry::Ui::ContextMenu::Component.new(**), &)
      end

      # The filterable command-palette listbox (the cmdk port): items DO
      # things - picking a VALUE for a form is Combobox territory.
      def poetry_command(**, &)
        render(Poetry::Ui::Command::Component.new(**), &)
      end

      # The ⌘K variant: a Command inside the Dialog chrome (sr-only
      # title/description) with the OPT-IN hotkey: global shortcut.
      def poetry_command_dialog(**, &)
        render(Poetry::Ui::Command::DialogComponent.new(**), &)
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
