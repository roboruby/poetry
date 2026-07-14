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

      def poetry_stat(**, &)
        render(Poetry::Ui::Stat::Component.new(**), &)
      end

      def poetry_metadata_list(**, &)
        render(Poetry::Ui::MetadataList::Component.new(**), &)
      end

      def poetry_toolbar(**, &)
        render(Poetry::Ui::Toolbar::Component.new(**), &)
      end

      def poetry_file_input(**, &)
        render(Poetry::Ui::FileInput::Component.new(**), &)
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

      # Data-driven pagination (N8): poetry_pagination(current:, total:,
      # path:) - path: is a callable ->(page) { url }; the component owns the
      # truncation math and the accessible nav.
      def poetry_pagination(**)
        render(Poetry::Ui::Pagination::Component.new(**))
      end

      # N8 static primitives.
      def poetry_skeleton(**, &)
        render(Poetry::Ui::Skeleton::Component.new(**), &)
      end

      def poetry_separator(**)
        render(Poetry::Ui::Separator::Component.new(**))
      end

      def poetry_spinner(**)
        render(Poetry::Ui::Spinner::Component.new(**))
      end

      # N13 W5: a deferred region - Turbo loading physics (lazy/eager) plus
      # poetry-owned placeholder and retryable-error states. The block is the
      # placeholder. See Deferred::Component.
      def poetry_deferred(**, &)
        render(Poetry::Ui::Deferred::Component.new(**), &)
      end

      # The key text is the content block: poetry_kbd { "⌘" }.
      def poetry_kbd(**, &)
        render(Poetry::Ui::Kbd::Component.new(**), &)
      end

      # ratio: is a string fraction ("16/9") - Ruby's 16/9 would truncate.
      def poetry_aspect_ratio(**, &)
        render(Poetry::Ui::AspectRatio::Component.new(**), &)
      end

      def poetry_empty(**, &)
        render(Poetry::Ui::Empty::Component.new(**), &)
      end

      # The server-driven DataTable (N8 W3): rows/state/path come from the
      # controller (State.from_params with a sortable: whitelist); columns
      # are declared in the block. Sorting/filter/page are URL state.
      def poetry_data_table(**, &)
        render(Poetry::Ui::DataTable::Component.new(**), &)
      end

      # N9 statics. The Avatar's content block is the initials fallback.
      def poetry_avatar(**, &)
        render(Poetry::Ui::Avatar::Component.new(**), &)
      end

      def poetry_breadcrumb(**, &)
        render(Poetry::Ui::Breadcrumb::Component.new(**), &)
      end

      def poetry_progress(**)
        render(Poetry::Ui::Progress::Component.new(**))
      end

      def poetry_item(**, &)
        render(Poetry::Ui::Item::Component.new(**), &)
      end

      # Part helpers (the Table pattern): pure class/slot stamps around
      # composed Avatars and Items.
      {
        avatar_group: [Poetry::Ui::Avatar, "avatar-group", :group, {}],
        avatar_group_count: [Poetry::Ui::Avatar, "avatar-group-count", :group_count, {}],
        item_group: [Poetry::Ui::Item, "item-group", :group, { "role" => "list" }]
      }.each do |name, (namespace, slot, element, extra)|
        define_method("poetry_#{name}") do |**attrs, &block|
          classes = [namespace::Style.css(element), attrs.delete(:class)].compact.join(" ")
          data = { slot: slot }.merge(attrs.delete(:data) || {})
          content_tag(:div, (capture(&block) if block), **extra, **attrs, class: classes, data: data)
        end
      end

      # The row divider inside an item group: the Separator with the
      # item-separator slot + spacing.
      def poetry_item_separator(**attrs)
        classes = [Poetry::Ui::Item::Style.css(:separator), attrs.delete(:class)].compact.join(" ")
        render(Poetry::Ui::Separator::Component.new(**attrs, class: classes, "data-slot": "item-separator"))
      end

      # The Calendar (N9 W6): a server-rendered month grid; name: makes it
      # a form control. poetry--core--calendar adds nav + selection.
      def poetry_calendar(**, &)
        render(Poetry::Ui::Calendar::Component.new(**), &)
      end

      # The DatePicker (N9 W6): a field-shaped trigger opening a Calendar in
      # a Popover; name: is the form field.
      def poetry_date_picker(**, &)
        render(Poetry::Ui::DatePicker::Component.new(**), &)
      end

      # The Sidebar (N9 W5): the app-shell frame - with_nav is the column,
      # with_inset the page area; poetry--core--sidebar owns the collapse.
      def poetry_sidebar(**, &)
        render(Poetry::Ui::Sidebar::Component.new(**), &)
      end

      # The collapse toggle (lives in the inset): a ghost icon Button wired
      # to the sidebar controller on the wrapper.
      def poetry_sidebar_trigger(**attrs)
        action = "click->poetry--core--sidebar#toggle"
        render(Poetry::Ui::Button::Component.new(
                 variant: :ghost, size: :"icon-sm", label: "Toggle Sidebar",
                 data: { slot: "sidebar-trigger", action: action }, **attrs
               )) { poetry_icon(name: :"panel-left") }
      end

      # The rail: an edge strip that toggles the sidebar (tabindex -1 - the
      # trigger is the keyboard affordance).
      def poetry_sidebar_rail(**attrs)
        classes = [Poetry::Ui::Sidebar::Style.css(:rail), attrs.delete(:class)].compact.join(" ")
        content_tag(:button, nil, type: "button", "aria-label": "Toggle Sidebar", tabindex: "-1",
                                  title: "Toggle Sidebar", class: classes,
                                  data: { slot: "sidebar-rail", action: "click->poetry--core--sidebar#toggle" },
                                  **attrs)
      end

      # The simple content-part stamps (div/ul/li wrappers with the slot +
      # dictionary classes).
      {
        sidebar_header: [:div, "sidebar-header", :header],
        sidebar_footer: [:div, "sidebar-footer", :footer],
        sidebar_content: [:div, "sidebar-content", :content],
        sidebar_group: [:div, "sidebar-group", :group],
        sidebar_group_content: [:div, "sidebar-group-content", :group_content],
        sidebar_menu: [:ul, "sidebar-menu", :menu],
        sidebar_menu_item: [:li, "sidebar-menu-item", :menu_item],
        sidebar_menu_sub: [:ul, "sidebar-menu-sub", :menu_sub],
        sidebar_menu_sub_item: [:li, "sidebar-menu-sub-item", :menu_sub_item]
      }.each do |name, (tag_name, slot, element)|
        define_method("poetry_#{name}") do |**attrs, &block|
          classes = [Poetry::Ui::Sidebar::Style.css(element), attrs.delete(:class)].compact.join(" ")
          data = { slot: slot }.merge(attrs.delete(:data) || {})
          content_tag(tag_name, (capture(&block) if block), **attrs, class: classes, data: data)
        end
      end

      def poetry_sidebar_group_label(**attrs, &block)
        classes = [Poetry::Ui::Sidebar::Style.css(:group_label), attrs.delete(:class)].compact.join(" ")
        content_tag(:div, (capture(&block) if block), **attrs, class: classes,
                                                               data: { slot: "sidebar-group-label" })
      end

      def poetry_sidebar_separator(**attrs)
        classes = [Poetry::Ui::Sidebar::Style.css(:separator), attrs.delete(:class)].compact.join(" ")
        render(Poetry::Ui::Separator::Component.new(**attrs, class: classes, "data-slot": "sidebar-separator"))
      end

      # A menu button: an anchor (href:) or a button, with the active state
      # + size variant. active: is the current route (data-active styles it).
      def poetry_sidebar_menu_button(href: nil, active: false, size: :default, **attrs, &block)
        style = Poetry::Ui::Sidebar::Style
        classes = [style.css(:menu_button), style.menu_button_size(size), attrs.delete(:class)].compact.join(" ")
        data = { slot: "sidebar-menu-button", size: size,
                 active: active ? "" : nil }.compact.merge(attrs.delete(:data) || {})
        if href
          content_tag(:a, (capture(&block) if block), href: href, class: classes, data: data,
                                                      "aria-current": active ? "page" : nil, **attrs)
        else
          content_tag(:button, (capture(&block) if block), type: "button", class: classes, data: data, **attrs)
        end
      end

      # An item-corner action (menu-action): absolutely positioned inside the
      # menu item (the menu button reserves pr-8 room via the group marker).
      # show_on_hover: keeps it invisible until the item is hovered/focused
      # on desktop.
      def poetry_sidebar_menu_action(show_on_hover: false, label: nil, **attrs, &block)
        style = Poetry::Ui::Sidebar::Style
        classes = [style.css(:menu_action), (style.css(:menu_action_hover) if show_on_hover),
                   attrs.delete(:class)].compact.join(" ")
        data = { slot: "sidebar-menu-action", sidebar: "menu-action" }.merge(attrs.delete(:data) || {})
        content_tag(:button, (capture(&block) if block), type: "button", class: classes, data: data,
                                                         "aria-label": label, **attrs)
      end

      # A trailing badge (menu-badge): count/status chrome in the item corner,
      # pointer-transparent.
      def poetry_sidebar_menu_badge(**attrs, &block)
        style = Poetry::Ui::Sidebar::Style
        classes = [style.css(:menu_badge), attrs.delete(:class)].compact.join(" ")
        data = { slot: "sidebar-menu-badge", sidebar: "menu-badge" }.merge(attrs.delete(:data) || {})
        content_tag(:div, (capture(&block) if block), class: classes, data: data, **attrs)
      end

      def poetry_sidebar_menu_sub_button(href: nil, active: false, **attrs, &block)
        style = Poetry::Ui::Sidebar::Style
        classes = [style.css(:menu_sub_button), attrs.delete(:class)].compact.join(" ")
        data = { slot: "sidebar-menu-sub-button",
                 active: active ? "" : nil }.compact.merge(attrs.delete(:data) || {})
        tag_name = href ? :a : :button
        extra = if href
                  { href: href, "aria-current": active ? "page" : nil }
                else
                  { type: "button" }
                end
        content_tag(tag_name, (capture(&block) if block), class: classes, data: data, **extra, **attrs)
      end

      # The NavigationMenu (N9 W4c): a disclosure bar - with_item for
      # trigger+panel, with_link for destinations; label: names the nav.
      def poetry_navigation_menu(**, &)
        render(Poetry::Ui::NavigationMenu::Component.new(**), &)
      end

      # A panel entry: a REAL link (active: marks the current page).
      def poetry_navigation_menu_link(href:, active: false, **attrs, &block)
        classes = [Poetry::Ui::NavigationMenu::Style.css(:link), attrs.delete(:class)].compact.join(" ")
        data = { slot: "navigation-menu-link", active: active ? "true" : nil }.compact
                                                                              .merge(attrs.delete(:data) || {})
        content_tag(:a, (capture(&block) if block), **attrs, href: href, class: classes, data: data)
      end

      # The Carousel (N9 W4): native scroll-snap slides - with_item per
      # slide; label: names the region.
      def poetry_carousel(**, &)
        render(Poetry::Ui::Carousel::Component.new(**), &)
      end

      # The Resizable panel group (N9 W4): with_panel x N; handles are
      # interleaved automatically (APG window splitters).
      def poetry_resizable(**, &)
        render(Poetry::Ui::Resizable::Component.new(**), &)
      end

      # The Drawer (N9 W3b): the swipeable edge dialog - trigger/title/
      # description/footer slots, direction: down/up/left/right.
      def poetry_drawer(**, &)
        render(Poetry::Ui::Drawer::Component.new(**), &)
      end

      # The native scroll region (N9 W3a): size it with classes; label: names it.
      def poetry_scroll_area(**, &)
        render(Poetry::Ui::ScrollArea::Component.new(**), &)
      end

      # Tabs (N9 W2): declare with with_tab(title, value:) + panel blocks;
      # the component owns the ARIA wiring and the two-controller split.
      def poetry_tabs(**, &)
        render(Poetry::Ui::Tabs::Component.new(**), &)
      end

      # N9 W1b form statics.
      def poetry_button_group(**, &)
        render(Poetry::Ui::ButtonGroup::Component.new(**), &)
      end

      def poetry_button_group_text(**attrs, &block)
        classes = [Poetry::Ui::ButtonGroup::Style.css(:text), attrs.delete(:class)].compact.join(" ")
        data = { slot: "button-group-text" }.merge(attrs.delete(:data) || {})
        content_tag(:div, (capture(&block) if block), **attrs, class: classes, data: data)
      end

      def poetry_button_group_separator(**attrs)
        classes = [Poetry::Ui::ButtonGroup::Style.css(:separator), attrs.delete(:class)].compact.join(" ")
        render(Poetry::Ui::Separator::Component.new(orientation: :vertical, **attrs, class: classes,
                                                    "data-slot": "button-group-separator"))
      end

      def poetry_native_select(**, &)
        render(Poetry::Ui::NativeSelect::Component.new(**), &)
      end

      def poetry_native_select_option(**attrs, &block)
        classes = [Poetry::Ui::NativeSelect::Style.css(:option), attrs.delete(:class)].compact.join(" ")
        data = { slot: "native-select-option" }.merge(attrs.delete(:data) || {})
        content_tag(:option, (capture(&block) if block), **attrs, class: classes, data: data)
      end

      def poetry_native_select_optgroup(**attrs, &block)
        classes = [Poetry::Ui::NativeSelect::Style.css(:optgroup), attrs.delete(:class)].compact.join(" ")
        data = { slot: "native-select-optgroup" }.merge(attrs.delete(:data) || {})
        content_tag(:optgroup, (capture(&block) if block), **attrs, class: classes, data: data)
      end

      def poetry_input_group(**, &)
        render(Poetry::Ui::InputGroup::Component.new(**), &)
      end

      INPUT_GROUP_ALIGNS = %i[inline-start inline-end block-start block-end].freeze

      def poetry_input_group_addon(align: :"inline-start", **attrs, &block)
        unless INPUT_GROUP_ALIGNS.include?(align.to_sym)
          raise ArgumentError, "InputGroup addon align: must be one of #{INPUT_GROUP_ALIGNS.inspect}"
        end

        style = Poetry::Ui::InputGroup::Style
        classes = [style.css(:addon), style.css(:"addon_#{align.to_s.tr("-", "_")}"),
                   attrs.delete(:class)].compact.join(" ")
        data = { slot: "input-group-addon", align: align }.merge(attrs.delete(:data) || {})
        content_tag(:div, (capture(&block) if block), **attrs, role: "group", class: classes, data: data)
      end

      def poetry_input_group_text(**attrs, &block)
        classes = [Poetry::Ui::InputGroup::Style.css(:text), attrs.delete(:class)].compact.join(" ")
        content_tag(:span, (capture(&block) if block), **attrs, class: classes)
      end

      # The borderless in-group control: the group wears the chrome; the
      # data-slot=input-group-control is what its focus/invalid selectors
      # key on.
      def poetry_input_group_input(**attrs)
        classes = [Poetry::Ui::InputGroup::Style.css(:control_input), attrs.delete(:class)].compact.join(" ")
        render(Poetry::Ui::Input::Component.new(**attrs, class: classes, "data-slot": "input-group-control"))
      end

      def poetry_input_group_textarea(**attrs)
        classes = [Poetry::Ui::InputGroup::Style.css(:control_textarea), attrs.delete(:class)].compact.join(" ")
        render(Poetry::Ui::Textarea::Component.new(**attrs, class: classes, "data-slot": "input-group-control"))
      end

      INPUT_GROUP_BUTTON_SIZES = %i[xs sm icon-xs icon-sm].freeze

      # The tiny in-group action: a ghost Button re-sized by the group's
      # dictionary (tailwind_merge lets h-6 beat the Button's own h-9).
      def poetry_input_group_button(size: :xs, **attrs, &)
        unless INPUT_GROUP_BUTTON_SIZES.include?(size.to_sym)
          raise ArgumentError, "InputGroup button size: must be one of #{INPUT_GROUP_BUTTON_SIZES.inspect}"
        end
        # Button's own icon-only guard keys off ITS size:, which this helper
        # bypasses - re-enforce the accessible-name rule here.
        if size.to_s.start_with?("icon") && attrs[:label].blank?
          raise ArgumentError, "icon-sized InputGroup button requires label: (the accessible name)"
        end

        style = Poetry::Ui::InputGroup::Style
        size_css = size.to_sym == :sm ? nil : style.css(:"button_#{size.to_s.tr("-", "_")}")
        classes = [style.css(:button), size_css, attrs.delete(:class)].compact.join(" ")
        render(Poetry::Ui::Button::Component.new(variant: :ghost, **attrs, class: classes,
                                                 "data-size": size), &)
      end

      # The value contracts runtime-enforced inside wrapper helpers, in
      # registry shape - emitted as the registry's "helpers" section
      # (rakelib/registry.rake) so poetry check and the MCP server validate
      # these literals statically (: the W2 filter_toolbar align:
      # :leading crash class). Plain wrapper helpers need no entry here;
      # registry generation lists them name-only.
      HELPER_CONTRACTS = {
        "poetry_input_group_addon" => {
          "options" => [{ "name" => "align", "type" => "symbol", "default" => "inline-start",
                          "variants" => INPUT_GROUP_ALIGNS.map(&:to_s) }]
        },
        "poetry_input_group_button" => {
          "options" => [{ "name" => "size", "type" => "symbol", "default" => "xs",
                          "variants" => INPUT_GROUP_BUTTON_SIZES.map(&:to_s) }]
        }
      }.freeze

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

      # Base UI's number-field pattern: a formatted text input
      # over a hidden type=number that submits the raw value; steppers
      # with press-and-hold; ArrowUp/Down (Shift/Alt sizes) on the input.
      def poetry_number_field(**)
        render(Poetry::Ui::NumberField::Component.new(**))
      end

      # The segmented date editor (the react-aria segment model):
      # a native input type=date (ISO on the wire, native pickers with no
      # JS) enhanced into per-segment spinbutton editing.
      def poetry_date_field(**)
        render(Poetry::Ui::DateField::Component.new(**))
      end

      # DateField at hour granularity: HH:MM[:SS] on the wire; the locale
      # decides 12- vs 24-hour editing (hour_cycle: pins it).
      def poetry_time_field(**)
        render(Poetry::Ui::TimeField::Component.new(**))
      end

      # A quantity within a known range (disk, seats, strength) - role
      # "meter progressbar" (the two-token fallback); never indeterminate.
      def poetry_meter(**)
        render(Poetry::Ui::Meter::Component.new(**))
      end

      # type=search on InputGroup chrome: Escape clears-then-dismisses,
      # focus-holding clear button, native WebKit affordances suppressed.
      def poetry_search_field(**)
        render(Poetry::Ui::SearchField::Component.new(**))
      end

      # Removable-chip collection (grid semantics, roving arrows, Delete
      # removal w/ focus recovery); name: serializes name[] per tag.
      def poetry_tag_group(**, &)
        render(Poetry::Ui::TagGroup::Component.new(**), &)
      end

      # Hierarchical expandable list (flat treegrid): items via the
      # nested with_item builder, expansion persisted by the host through
      # poetry:tree:toggle.
      def poetry_tree(**, &)
        render(Poetry::Ui::Tree::Component.new(**), &)
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
