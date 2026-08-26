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
      # Triggers an action or event, such as submitting a form or opening a
      # dialog.
      #
      # @example
      #     poetry_button(variant: :default) { "Save" }
      # @see Poetry::Ui::Button::Component
      def poetry_button(**, &)
        render(Poetry::Ui::Button::Component.new(**), &)
      end

      # Renders an inline SVG icon from the icon set.
      #
      # @example A decorative icon inside a labeled control
      #     poetry_icon(name: :plus)
      # @see Poetry::Ui::Icon::Component
      def poetry_icon(**)
        render(Poetry::Ui::Icon::Component.new(**))
      end

      # A styled navigational hyperlink.
      #
      # @example
      #     poetry_link(href: "/docs") { "Documentation" }
      # @see Poetry::Ui::Link::Component
      def poetry_link(**, &)
        render(Poetry::Ui::Link::Component.new(**), &)
      end

      # A small count or status descriptor.
      #
      # @example A soft status pill
      #     poetry_badge(variant: :success) { "Fulfilled" }
      # @see Poetry::Ui::Badge::Component
      def poetry_badge(**, &)
        render(Poetry::Ui::Badge::Component.new(**), &)
      end

      # A single KPI: a muted label over a large metric value.
      #
      # @example Revenue KPI with a delta
      #     poetry_stat(label: "Revenue", delta: "+12.5%", trend: :up) do
      #       "$45,231"
      #     end
      # @see Poetry::Ui::Stat::Component
      def poetry_stat(**, &)
        render(Poetry::Ui::Stat::Component.new(**), &)
      end

      # A key-value list for labeled attributes on detail pages.
      #
      # @example A record's fact sheet
      #     poetry_metadata_list(columns: :two) do |list|
      #       list.with_item(label: "Status") { "Active" }
      #       list.with_item(label: "Owner") { "Ada Lovelace" }
      #     end
      # @see Poetry::Ui::MetadataList::Component
      def poetry_metadata_list(**, &)
        render(Poetry::Ui::MetadataList::Component.new(**), &)
      end

      # A sequence of dated events as an ordered list.
      #
      # @example
      #     poetry_timeline do |timeline|
      #       timeline.with_item(title: "Order placed", time: "Mar 15", completed: true)
      #       timeline.with_item(title: "In transit") { "Estimated delivery Thursday." }
      #     end
      # @see Poetry::Ui::Timeline::Component
      def poetry_timeline(**, &)
        render(Poetry::Ui::Timeline::Component.new(**), &)
      end

      # A horizontal group of controls that acts as one keyboard tab stop -
      # Tab passes over the group, Arrow keys move between its controls.
      #
      # @example
      #     poetry_toolbar(label: "Bulk actions") do |toolbar|
      #       toolbar.with_button(variant: :outline) { "Archive" }
      #       toolbar.with_separator
      #       toolbar.with_input(name: "q", placeholder: "Filter…")
      #     end
      # @see Poetry::Ui::Toolbar::Component
      def poetry_toolbar(**, &)
        render(Poetry::Ui::Toolbar::Component.new(**), &)
      end

      # Prose styling for long-form and rendered-markdown content.
      #
      # @example
      #     poetry_typeset(preset: "docs") do
      #       @article_html
      #     end
      # @see Poetry::Ui::Typeset::Component
      def poetry_typeset(**, &)
        render(Poetry::Ui::Typeset::Component.new(**), &)
      end

      # A control for selecting, previewing, and removing files to upload.
      #
      # @example Drag-and-drop upload surface
      #     poetry_file_input(
      #       variant: :dropzone, name: "attachments[]", multiple: true,
      #       hint: "PDF or PNG, up to 10 MB"
      #     )
      # @see Poetry::Ui::FileInput::Component
      def poetry_file_input(**, &)
        render(Poetry::Ui::FileInput::Component.new(**), &)
      end

      # A callout that highlights an important inline message.
      #
      # @example Destructive alert with a title
      #     poetry_alert(variant: :destructive) do |alert|
      #       alert.with_title { "Payment failed" }
      #       "Your card was declined. Update your billing details."
      #     end
      # @see Poetry::Ui::Alert::Component
      def poetry_alert(**, &)
        render(Poetry::Ui::Alert::Component.new(**), &)
      end

      # A container that groups related content and actions.
      #
      # @example
      #     poetry_card do |card|
      #       card.with_title { "Team" }
      #       card.with_description { "Invite and manage members." }
      #       "Body content"
      #     end
      # @see Poetry::Ui::Card::Component
      def poetry_card(**, &)
        render(Poetry::Ui::Card::Component.new(**), &)
      end

      # The Table: the component renders the overflow container + real
      # `<table>`; the part helpers stamp the data-slot + source-exact classes
      # onto the semantic table elements the consumer composes.
      #
      # @example
      #     poetry_table do
      #       safe_join([
      #         poetry_table_header { poetry_table_row { poetry_table_head { "Invoice" } } },
      #         poetry_table_body { poetry_table_row { poetry_table_cell { "INV001" } } }
      #       ])
      #     end
      # @see Poetry::Ui::Table::Component
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

      # Data-driven pagination: poetry_pagination(current:, total:,
      # path:) - path: is a callable ->(page) { url }; the component owns the
      # truncation math and the accessible nav.
      #
      # @example Paginating a product list
      #     poetry_pagination(current: 3, total: 12,
      #                                                  path: ->(page) { products_path(page: page) })
      # @see Poetry::Ui::Pagination::Component
      def poetry_pagination(**)
        render(Poetry::Ui::Pagination::Component.new(**))
      end

      # A pulsing placeholder shown while content loads.
      #
      # @example An avatar-and-line placeholder pair
      #     poetry_skeleton(class: "size-10 rounded-full")
      #     poetry_skeleton(class: "h-4 w-32")
      # @see Poetry::Ui::Skeleton::Component
      def poetry_skeleton(**, &)
        render(Poetry::Ui::Skeleton::Component.new(**), &)
      end

      # A thin divider between content, decorative or semantic.
      #
      # @example Horizontal divider between sections
      #     poetry_separator
      # @see Poetry::Ui::Separator::Component
      def poetry_separator(**)
        render(Poetry::Ui::Separator::Component.new(**))
      end

      # An indeterminate loading indicator that announces itself.
      #
      # @example
      #     poetry_spinner(label: "Saving...")
      # @see Poetry::Ui::Spinner::Component
      def poetry_spinner(**)
        render(Poetry::Ui::Spinner::Component.new(**))
      end

      # A deferred region - Turbo loading physics (lazy/eager) plus
      # poetry-owned placeholder and retryable-error states. The block is the
      # placeholder.
      #
      # @example
      #     poetry_deferred(src: "/dashboard/activity")
      # @see Poetry::Ui::Deferred::Component
      def poetry_deferred(**, &)
        render(Poetry::Ui::Deferred::Component.new(**), &)
      end

      # Optimistic UI for a Turbo form: the block's
      # form.optimistic_template authors the PREDICTED state as a
      # turbo-stream in a <template>; the controller paints it on submit
      # and reconciles (morph refresh) only when the server rejects. The
      # server contract - success answers 204 or a targeted stream, NEVER
      # a redirect; failure answers 4xx - and the morph-refresh meta
      # prerequisite live in the Optimistic Forms guide on the docs site.
      # attribute_name:/value: auto-inject the submitted-value hidden field
      # (false survives; form.optimistic_hidden_field places it explicitly).
      #
      # @example
      #   <%= poetry_optimistic_form(model: task, attribute_name: :done, value: true) do |form| %>
      #     <%= form.optimistic_template do %>
      #       <%# the predicted turbo-stream(s) %>
      #     <% end %>
      #     <%= form.submit "Done" %>
      #   <% end %>
      # @see Poetry::Ui::OptimisticFormBuilder
      def poetry_optimistic_form(attribute_name: nil, value: OptimisticFormBuilder::UNSET,
                                 **options, &block)
        options[:builder] = OptimisticFormBuilder
        options[:data] = (options[:data] || {}).dup
        options[:data][:controller] =
          [options[:data][:controller], "poetry--core--optimistic-form"].compact.join(" ")
        optimistic = Poetry::Core::Stimulus::Builder.new("poetry--core--optimistic-form",
                                                         Poetry::Core::HTML::Attributes.new)
        options[:data][:action] = [
          options[:data][:action],
          optimistic.action(:apply, on: "turbo:submit-start"),
          optimistic.action(:reconcile, on: "turbo:submit-end")
        ].compact.join(" ")

        form_with(**options) do |form|
          body = capture(form, &block)
          prefix = if optimistic_auto_inject?(form, attribute_name, value)
                     form.optimistic_hidden_field(attribute_name, value: value)
                   end
          safe_join([prefix, body].compact)
        end
      end

      # Declares a form as a WebMCP tool - the declarative registration
      # path: the <form> carries toolname/tooldescription, so a WebMCP
      # browser registers it as an agent-callable tool with NO JavaScript
      # (the parameter schema is synthesized from the controls; each
      # parameter's description comes from its <label>, so the poetry
      # FormBuilder's model-derived labels describe the tool for free;
      # tool_description: on a field overrides one). Defaults the builder
      # to Poetry::Ui::FormBuilder. autosubmit: true is GET-only by
      # construction - a mutating form always keeps the user's Submit.
      #
      # @example A read-only lookup the agent may submit itself
      #   <%= poetry_webmcp_form(url: orders_path, method: :get,
      #                          tool: { name: "find_orders", description: "Search orders by timeframe.",
      #                                  autosubmit: true }) do |form| %>
      #     <%= form.field(:timeframe, tool_description: "A relative range such as last_7_days.") %>
      #   <% end %>
      # @see Poetry::Ui::Webmcp
      def poetry_webmcp_form(tool:, **options, &)
        options[:builder] ||= FormBuilder
        options[:html] = (options[:html] || {}).merge(Webmcp.form_attributes(tool, method: options[:method]))
        # The poetry-agent form controller answers an agent-invoked submit
        # with the outcome (SubmitEvent.respondWith); without the runtime
        # gem the token is inert and the browser's own submission runs.
        options[:data] = (options[:data] || {}).dup
        options[:data][:controller] = [options[:data][:controller], Webmcp::FORM_CONTROLLER].compact.join(" ")
        form_with(**options, &)
      end

      # The key text is the content block: poetry_kbd { "⌘" }.
      #
      # @example
      #     poetry_kbd { "Esc" }
      # @see Poetry::Ui::Kbd::Component
      def poetry_kbd(**, &)
        render(Poetry::Ui::Kbd::Component.new(**), &)
      end

      # A run of key chords (upstream KbdGroup): a wrapping <kbd> carrying
      # the themed gap - poetry_kbd children render inside.
      #
      # @example
      #   <%= poetry_kbd_group do %>
      #     <%= poetry_kbd { "⌘" } %><%= poetry_kbd { "K" } %>
      #   <% end %>
      # @see Poetry::Ui::Kbd::Component
      def poetry_kbd_group(**attrs, &)
        classes = ["cn-kbd-group inline-flex items-center", attrs.delete(:class)].compact.join(" ")
        content_tag(:kbd, capture(&), class: classes, "data-slot": "kbd-group", **attrs)
      end

      # ratio: is a string fraction ("16/9") - Ruby's 16/9 would truncate.
      #
      # @example A 16:9 media box
      #     poetry_aspect_ratio(ratio: "16/9") do
      #       image_tag "cover.jpg", class: "size-full object-cover"
      #     end
      # @see Poetry::Ui::AspectRatio::Component
      def poetry_aspect_ratio(**, &)
        render(Poetry::Ui::AspectRatio::Component.new(**), &)
      end

      # An empty-state placeholder with an icon, message, and actions.
      #
      # @example Empty collection with a next action
      #     poetry_empty do |empty|
      #       empty.with_title { "No projects yet" }
      #       empty.with_description { "Create your first project to get started." }
      #       poetry_button { "New project" }
      #     end
      # @see Poetry::Ui::Empty::Component
      def poetry_empty(**, &)
        render(Poetry::Ui::Empty::Component.new(**), &)
      end

      # The server-driven DataTable: rows/state/path come from the
      # controller (State.from_params with a sortable: whitelist); columns
      # are declared in the block. Sorting/filter/page are URL state.
      #
      # @example A sortable notes table
      #     <%= poetry_data_table(rows: @notes, state: state, total: @pages,
      #                           path: ->(p) { notes_path(**p) }, caption: "Notes") do |t| %>
      #       <% t.with_column("Title", key: :title, sortable: true) { |note| note.title } %>
      #       <% t.with_column("Created", key: :created_at, sortable: true) { |note| note.created_at.to_date } %>
      #     <% end %>
      # @see Poetry::Ui::DataTable::Component
      def poetry_data_table(**, &)
        render(Poetry::Ui::DataTable::Component.new(**), &)
      end

      # An input that suggests options as you type - the text itself is the
      # value.
      #
      # @example Free text with suggestions
      #     poetry_autocomplete(name: "tag", label: "Search tags") do |auto|
      #       auto.with_item(label: "feature")
      #       auto.with_item(label: "fix")
      #     end
      # @see Poetry::Ui::Autocomplete::Component
      def poetry_autocomplete(**, &)
        render(Poetry::Ui::Autocomplete::Component.new(**), &)
      end

      # The content block is the initials fallback.
      #
      # @example Image with initials fallback
      #     poetry_avatar(src: user.avatar_url, label: "Ada Lovelace") { "AL" }
      # @see Poetry::Ui::Avatar::Component
      def poetry_avatar(**, &)
        render(Poetry::Ui::Avatar::Component.new(**), &)
      end

      # Shows the path to the current page as a trail of links.
      #
      # @example
      #     <%= poetry_breadcrumb do |crumb| %>
      #       <% crumb.with_item("Home", href: "/") %>
      #       <% crumb.with_ellipsis %>
      #       <% crumb.with_item("Breadcrumb") %>
      #     <% end %>
      # @see Poetry::Ui::Breadcrumb::Component
      def poetry_breadcrumb(**, &)
        render(Poetry::Ui::Breadcrumb::Component.new(**), &)
      end

      # A determinate progress bar toward task completion.
      #
      # @example
      #     poetry_progress(value: 60, label: "Uploading")
      # @see Poetry::Ui::Progress::Component
      def poetry_progress(**)
        render(Poetry::Ui::Progress::Component.new(**))
      end

      # A generic list row with media, content, and actions.
      #
      # @example
      #     poetry_item(variant: :outline) do |item|
      #       item.with_title { "Backups" }
      #       item.with_description { "Nightly, retained 30 days" }
      #     end
      # @see Poetry::Ui::Item::Component
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
      #
      # @example
      #   poetry_item_separator
      # @see Poetry::Ui::Item::Component
      def poetry_item_separator(**attrs)
        classes = [Poetry::Ui::Item::Style.css(:separator), attrs.delete(:class)].compact.join(" ")
        render(Poetry::Ui::Separator::Component.new(**attrs, class: classes, "data-slot": "item-separator"))
      end

      # The Calendar: a server-rendered month grid; name: makes it
      # a form control. poetry--core--calendar adds nav + selection.
      #
      # @example A form-posting date pick
      #     poetry_calendar(name: "event[date]", selected: "2026-07-04")
      # @see Poetry::Ui::Calendar::Component
      def poetry_calendar(**, &)
        render(Poetry::Ui::Calendar::Component.new(**), &)
      end

      # The DatePicker: a field-shaped trigger opening a Calendar in
      # a Popover; name: is the form field.
      #
      # @example
      #     poetry_date_picker(
      #       name: "due_on", label: "Due date", value: Date.new(2026, 6, 5)
      #     )
      # @see Poetry::Ui::DatePicker::Component
      def poetry_date_picker(**, &)
        render(Poetry::Ui::DatePicker::Component.new(**), &)
      end

      # The Sidebar: the app-shell frame - with_nav is the column,
      # with_inset the page area; poetry--core--sidebar owns the collapse.
      #
      # @example App shell wired to the persisted cookie
      #     <%= poetry_sidebar(open: cookies[:sidebar_state] != "false", collapsible: :icon) do |shell| %>
      #       <% shell.with_nav do %>
      #         <%= poetry_sidebar_group do %>...menu...<% end %>
      #       <% end %>
      #       <% shell.with_inset do %>
      #         <%= poetry_sidebar_trigger %>
      #         <main>...page...</main>
      #       <% end %>
      #     <% end %>
      # @see Poetry::Ui::Sidebar::Component
      def poetry_sidebar(**, &)
        render(Poetry::Ui::Sidebar::Component.new(**), &)
      end

      # Client-side toast delivery: pressing the trigger clones the
      # addressed <template>'s toast into the toaster region - no server
      # round-trip.
      #
      # @example
      #     <%= poetry_toast_trigger(template: "copied-toast") do %>
      #       Copy link
      #     <% end %>
      #     <template id="copied-toast">
      #       <%= poetry_toast(duration: 4000) do |toast| %>
      #         <% toast.with_title { "Copied" } %>
      #       <% end %>
      #     </template>
      # @see Poetry::Ui::ToastTrigger::Component
      def poetry_toast_trigger(**, &)
        render(Poetry::Ui::ToastTrigger::Component.new(**), &)
      end

      # The sidebar collapse toggle (lives in the inset): a ghost icon
      # Button wired to the sidebar controller on the wrapper.
      #
      # @example
      #   poetry_sidebar_trigger
      # @see Poetry::Ui::Sidebar::Component
      def poetry_sidebar_trigger(**attrs)
        action = Poetry::Ui::Sidebar::Component.stimulus_action(:toggle, on: :click)
        # A caller data: hash augments the toggle wiring instead of
        # replacing it at the kwargs splat (actions token-join).
        caller_data = attrs.delete(:data) || {}
        data = { slot: "sidebar-trigger", action: action }.merge(caller_data) do |key, wired, caller|
          key == :action ? Poetry::Core::Config.current.stimulus_merger.merge_actions(wired, caller) : caller
        end
        render(Poetry::Ui::Button::Component.new(
                 variant: :ghost, size: :"icon-sm", label: "Toggle Sidebar",
                 data: data, **attrs
               )) { poetry_icon(name: :"panel-left") }
      end

      # The rail: an edge strip that toggles the sidebar (tabindex -1 - the
      # trigger is the keyboard affordance).
      #
      # @example
      #   poetry_sidebar_rail
      # @see Poetry::Ui::Sidebar::Component
      def poetry_sidebar_rail(**attrs)
        classes = [Poetry::Ui::Sidebar::Style.css(:rail), attrs.delete(:class)].compact.join(" ")
        wiring = { type: "button", "aria-label": "Toggle Sidebar", tabindex: "-1",
                   title: "Toggle Sidebar", class: classes,
                   data: { slot: "sidebar-rail",
                           action: Poetry::Ui::Sidebar::Component.stimulus_action(:toggle, on: :click) } }
        content_tag(:button, nil, Poetry::Core::HTML::Attributes.merged(wiring, attrs))
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

      # The group heading: a muted label above a sidebar menu.
      #
      # @example
      #   poetry_sidebar_group_label { "Projects" }
      # @see Poetry::Ui::Sidebar::Component
      def poetry_sidebar_group_label(**attrs, &block)
        classes = [Poetry::Ui::Sidebar::Style.css(:group_label), attrs.delete(:class)].compact.join(" ")
        content_tag(:div, (capture(&block) if block), **attrs, class: classes,
                                                               data: { slot: "sidebar-group-label" })
      end

      # The themed divider between sidebar groups.
      #
      # @example
      #   poetry_sidebar_separator
      # @see Poetry::Ui::Sidebar::Component
      def poetry_sidebar_separator(**attrs)
        classes = [Poetry::Ui::Sidebar::Style.css(:separator), attrs.delete(:class)].compact.join(" ")
        render(Poetry::Ui::Separator::Component.new(**attrs, class: classes, "data-slot": "sidebar-separator"))
      end

      # A menu button: an anchor (href:) or a button, with the active state
      # + size and variant axes. active: is the current route (data-active
      # styles it); variant: :outline draws the bordered treatment.
      #
      # @example
      #   poetry_sidebar_menu_button(href: "/projects", active: true) { "Projects" }
      # @see Poetry::Ui::Sidebar::Component
      def poetry_sidebar_menu_button(href: nil, active: false, size: :default,
                                     variant: :default, **attrs, &block)
        unless %i[default outline].include?(variant.to_sym)
          raise ArgumentError, "sidebar menu button variant: must be :default or :outline"
        end

        style = Poetry::Ui::Sidebar::Style
        classes = [style.css(:menu_button), style.menu_button_size(size),
                   "cn-sidebar-menu-button-variant-#{variant}", attrs.delete(:class)].compact.join(" ")
        data = { slot: "sidebar-menu-button", size: size, variant: variant,
                 active: active ? "" : nil }.compact.merge(attrs.delete(:data) || {})
        if href
          content_tag(:a, (capture(&block) if block), href: href, class: classes, data: data,
                                                      "aria-current": active ? "page" : nil, **attrs)
        else
          content_tag(:button, (capture(&block) if block), type: "button", class: classes, data: data, **attrs)
        end
      end

      # The group-corner action (upstream SidebarGroupAction): pinned to the
      # group's top-right by the theme.
      #
      # @example
      #   poetry_sidebar_group_action(label: "Add project") { poetry_icon(name: :plus) }
      # @see Poetry::Ui::Sidebar::Component
      def poetry_sidebar_group_action(label: nil, **attrs, &block)
        classes = [Poetry::Ui::Sidebar::Style.css(:group_action_button), attrs.delete(:class)].compact.join(" ")
        data = { slot: "sidebar-group-action", sidebar: "group-action" }.merge(attrs.delete(:data) || {})
        content_tag(:button, (capture(&block) if block), type: "button", class: classes, data: data,
                                                         "aria-label": label, **attrs)
      end

      # The sidebar search input (upstream SidebarInput): the themed Input
      # sized for the header well.
      #
      # @example
      #   poetry_sidebar_input(placeholder: "Search...")
      # @see Poetry::Ui::Sidebar::Component
      def poetry_sidebar_input(**attrs)
        classes = [Poetry::Ui::Sidebar::Style.css(:input_control), attrs.delete(:class)].compact.join(" ")
        render(Poetry::Ui::Input::Component.new(**attrs, class: classes, "data-slot": "sidebar-input"))
      end

      # A loading placeholder row (upstream SidebarMenuSkeleton): optional
      # leading icon block + a text bar with a random-ish width the caller
      # can pin via text_width:.
      #
      # @example
      #   poetry_sidebar_menu_skeleton(icon: true)
      # @see Poetry::Ui::Sidebar::Component
      def poetry_sidebar_menu_skeleton(icon: false, text_width: "70%", **attrs)
        classes = [Poetry::Ui::Sidebar::Style.css(:menu_skeleton), attrs.delete(:class)].compact.join(" ")
        data = { slot: "sidebar-menu-skeleton" }.merge(attrs.delete(:data) || {})
        content_tag(:div, class: classes, data: data, **attrs) do
          safe_join([
            (if icon
               render(Poetry::Ui::Skeleton::Component.new(class: Poetry::Ui::Sidebar::Style.css(:menu_skeleton_icon),
                                                          "data-slot": "sidebar-menu-skeleton-icon"))
             end),
            render(Poetry::Ui::Skeleton::Component.new(class: Poetry::Ui::Sidebar::Style.css(:menu_skeleton_text),
                                                       "data-slot": "sidebar-menu-skeleton-text",
                                                       style: "--skeleton-width: #{text_width}"))
          ].compact)
        end
      end

      # An item-corner action (menu-action): absolutely positioned inside the
      # menu item (the menu button reserves pr-8 room via the group marker).
      # show_on_hover: keeps it invisible until the item is hovered/focused
      # on desktop.
      #
      # @example
      #   poetry_sidebar_menu_action(label: "More", show_on_hover: true) { poetry_icon(name: :ellipsis) }
      # @see Poetry::Ui::Sidebar::Component
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
      #
      # @example
      #   poetry_sidebar_menu_badge { "24" }
      # @see Poetry::Ui::Sidebar::Component
      def poetry_sidebar_menu_badge(**attrs, &block)
        style = Poetry::Ui::Sidebar::Style
        classes = [style.css(:menu_badge), attrs.delete(:class)].compact.join(" ")
        data = { slot: "sidebar-menu-badge", sidebar: "menu-badge" }.merge(attrs.delete(:data) || {})
        content_tag(:div, (capture(&block) if block), class: classes, data: data, **attrs)
      end

      # A nested menu entry: an anchor (href:) or a button; active: marks
      # the current route (aria-current + data-active).
      #
      # @example
      #   poetry_sidebar_menu_sub_button(href: "/settings") { "Settings" }
      # @see Poetry::Ui::Sidebar::Component
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

      # The NavigationMenu: a disclosure bar - with_item for
      # trigger+panel, with_link for destinations; label: names the nav.
      #
      # @example Disclosure bar with a panel and a link
      #     <%= poetry_navigation_menu(label: "Main") do |nav| %>
      #       <% nav.with_item("Products", value: "products") do %>
      #         <%= poetry_navigation_menu_link(href: products_path) { "All products" } %>
      #       <% end %>
      #       <% nav.with_link("Docs", href: docs_path) %>
      #     <% end %>
      # @see Poetry::Ui::NavigationMenu::Component
      def poetry_navigation_menu(**, &)
        render(Poetry::Ui::NavigationMenu::Component.new(**), &)
      end

      # A panel entry: a REAL link (active: marks the current page).
      #
      # @example
      #   poetry_navigation_menu_link(href: "/docs", active: true) { "Docs" }
      # @see Poetry::Ui::NavigationMenu::Component
      def poetry_navigation_menu_link(href:, active: false, **attrs, &block)
        classes = [Poetry::Ui::NavigationMenu::Style.css(:link), attrs.delete(:class)].compact.join(" ")
        data = { slot: "navigation-menu-link", active: active ? "true" : nil }.compact
                                                                              .merge(attrs.delete(:data) || {})
        content_tag(:a, (capture(&block) if block), **attrs, href: href, class: classes, data: data)
      end

      # The Carousel: native scroll-snap slides - with_item per
      # slide; label: names the region.
      #
      # @example
      #     poetry_carousel(label: "Featured") do |carousel|
      #       carousel.with_item { "Slide one" }
      #       carousel.with_item { "Slide two" }
      #     end
      # @see Poetry::Ui::Carousel::Component
      def poetry_carousel(**, &)
        render(Poetry::Ui::Carousel::Component.new(**), &)
      end

      # The Resizable panel group: with_panel x N; handles are
      # interleaved automatically (APG window splitters).
      #
      # @example
      #     poetry_resizable(class: "h-48 rounded-lg border") do |group|
      #       group.with_panel(default_size: 25) { tag.div("Sidebar") }
      #       group.with_panel { tag.div("Content") }
      #     end
      # @see Poetry::Ui::Resizable::Component
      def poetry_resizable(**, &)
        render(Poetry::Ui::Resizable::Component.new(**), &)
      end

      # The Drawer: the swipeable edge dialog - trigger/title/
      # description/footer slots, direction: down/up/left/right.
      #
      # @example
      #     poetry_drawer(show_swipe_handle: true) do |drawer|
      #       drawer.with_trigger { "Open drawer" }
      #       drawer.with_title { "Move goal" }
      #       drawer.with_description { "Set your daily activity goal." }
      #       "Drawer body"
      #     end
      # @see Poetry::Ui::Drawer::Component
      def poetry_drawer(**, &)
        render(Poetry::Ui::Drawer::Component.new(**), &)
      end

      # The native scroll region: size it with classes; label: names it.
      #
      # @example A bounded list that scrolls
      #     poetry_scroll_area(label: "Tags", class: "h-72 w-48") do
      #       safe_join(tags.map { |tag| tag.name })
      #     end
      # @see Poetry::Ui::ScrollArea::Component
      def poetry_scroll_area(**, &)
        render(Poetry::Ui::ScrollArea::Component.new(**), &)
      end

      # Tabs: declare with with_tab(title, value:) + panel blocks;
      # the component owns the ARIA wiring and the two-controller split.
      #
      # @example
      #     <%= poetry_tabs(default: "account", label: "Account settings") do |tabs| %>
      #       <% tabs.with_tab("Account", value: "account") do %>...panel...<% end %>
      #       <% tabs.with_tab("Password", value: "password") do %>...panel...<% end %>
      #     <% end %>
      # @see Poetry::Ui::Tabs::Component
      def poetry_tabs(**, &)
        render(Poetry::Ui::Tabs::Component.new(**), &)
      end

      # Visually joins adjacent buttons and controls into one group.
      #
      # @example A segmented pair
      #     poetry_button_group("aria-label": "Alignment") do
      #       safe_join([
      #         poetry_button(variant: :outline) { "Left" },
      #         poetry_button(variant: :outline) { "Right" }
      #       ])
      #     end
      # @see Poetry::Ui::ButtonGroup::Component
      def poetry_button_group(**, &)
        render(Poetry::Ui::ButtonGroup::Component.new(**), &)
      end

      # Non-interactive text inside a ButtonGroup run.
      #
      # @example
      #   poetry_button_group_text { "of 12" }
      # @see Poetry::Ui::ButtonGroup::Component
      def poetry_button_group_text(**attrs, &block)
        classes = [Poetry::Ui::ButtonGroup::Style.css(:text), attrs.delete(:class)].compact.join(" ")
        data = { slot: "button-group-text" }.merge(attrs.delete(:data) || {})
        content_tag(:div, (capture(&block) if block), **attrs, class: classes, data: data)
      end

      # The vertical divider between grouped controls.
      #
      # @example
      #   poetry_button_group_separator
      # @see Poetry::Ui::ButtonGroup::Component
      def poetry_button_group_separator(**attrs)
        classes = [Poetry::Ui::ButtonGroup::Style.css(:separator), attrs.delete(:class)].compact.join(" ")
        render(Poetry::Ui::Separator::Component.new(orientation: :vertical, **attrs, class: classes,
                                                    "data-slot": "button-group-separator"))
      end

      # A styled wrapper around the real native select control.
      #
      # @example The options: fast path
      #     poetry_native_select(
      #       name: "sort", label: "Sort by",
      #       options: [["Newest first", "newest"], ["Oldest first", "oldest"]],
      #       selected: "newest"
      #     )
      # @see Poetry::Ui::NativeSelect::Component
      def poetry_native_select(**, &)
        render(Poetry::Ui::NativeSelect::Component.new(**), &)
      end

      # One styled <option> inside poetry_native_select.
      #
      # @example
      #   poetry_native_select_option(value: "us") { "United States" }
      # @see Poetry::Ui::NativeSelect::Component
      def poetry_native_select_option(**attrs, &block)
        classes = [Poetry::Ui::NativeSelect::Style.css(:option), attrs.delete(:class)].compact.join(" ")
        data = { slot: "native-select-option" }.merge(attrs.delete(:data) || {})
        content_tag(:option, (capture(&block) if block), **attrs, class: classes, data: data)
      end

      # A styled <optgroup> inside poetry_native_select.
      #
      # @example
      #   poetry_native_select_optgroup(label: "Europe") do
      #     poetry_native_select_option(value: "fr") { "France" }
      #   end
      # @see Poetry::Ui::NativeSelect::Component
      def poetry_native_select_optgroup(**attrs, &block)
        classes = [Poetry::Ui::NativeSelect::Style.css(:optgroup), attrs.delete(:class)].compact.join(" ")
        data = { slot: "native-select-optgroup" }.merge(attrs.delete(:data) || {})
        content_tag(:optgroup, (capture(&block) if block), **attrs, class: classes, data: data)
      end

      # One bordered surface combining an input with buttons, icons, or
      # add-ons.
      #
      # @example
      #     <%= poetry_input_group do %>
      #       <%= poetry_input_group_addon do %>
      #         <%= poetry_icon(name: :search) %>
      #       <% end %>
      #       <%= poetry_input_group_input(name: "q", placeholder: "Search...") %>
      #     <% end %>
      # @see Poetry::Ui::InputGroup::Component
      def poetry_input_group(**, &)
        render(Poetry::Ui::InputGroup::Component.new(**), &)
      end

      # The valid align: values for poetry_input_group_addon.
      INPUT_GROUP_ALIGNS = %i[inline-start inline-end block-start block-end].freeze

      # An addon region inside an InputGroup - icons, text, or small
      # buttons aligned to one of the four edges of the group.
      #
      # @example
      #   poetry_input_group_addon(align: :"inline-end") { poetry_icon(name: :search) }
      # @see Poetry::Ui::InputGroup::Component
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

      # Inline text inside an InputGroup - prefixes, suffixes, hints.
      #
      # @example
      #   poetry_input_group_text { "https://" }
      # @see Poetry::Ui::InputGroup::Component
      def poetry_input_group_text(**attrs, &block)
        classes = [Poetry::Ui::InputGroup::Style.css(:text), attrs.delete(:class)].compact.join(" ")
        content_tag(:span, (capture(&block) if block), **attrs, class: classes)
      end

      # The borderless in-group control: the group wears the chrome; the
      # data-slot=input-group-control is what its focus/invalid selectors
      # key on.
      #
      # @example
      #   poetry_input_group_input(placeholder: "Search...")
      # @see Poetry::Ui::InputGroup::Component
      def poetry_input_group_input(**attrs)
        classes = [Poetry::Ui::InputGroup::Style.css(:control_input), attrs.delete(:class)].compact.join(" ")
        render(Poetry::Ui::Input::Component.new(**attrs, class: classes, "data-slot": "input-group-control"))
      end

      # The borderless multiline in-group control - the group wears the
      # chrome, like poetry_input_group_input.
      #
      # @example
      #   poetry_input_group_textarea(placeholder: "Add a note...")
      # @see Poetry::Ui::InputGroup::Component
      def poetry_input_group_textarea(**attrs)
        classes = [Poetry::Ui::InputGroup::Style.css(:control_textarea), attrs.delete(:class)].compact.join(" ")
        render(Poetry::Ui::Textarea::Component.new(**attrs, class: classes, "data-slot": "input-group-control"))
      end

      # The valid size: values for poetry_input_group_button.
      INPUT_GROUP_BUTTON_SIZES = %i[xs sm icon-xs icon-sm].freeze

      # The tiny in-group action: a ghost Button re-sized by the group's
      # dictionary (tailwind_merge lets h-6 beat the Button's own h-9).
      #
      # @example
      #   poetry_input_group_button(size: :"icon-xs", label: "Copy") { poetry_icon(name: :copy) }
      # @see Poetry::Ui::InputGroup::Component
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
        size_css = style.css(:"button_#{size.to_s.tr("-", "_")}")
        classes = [style.css(:button), size_css, attrs.delete(:class)].compact.join(" ")
        render(Poetry::Ui::Button::Component.new(variant: :ghost, **attrs, class: classes,
                                                 "data-size": size), &)
      end

      # The value contracts runtime-enforced inside wrapper helpers, in
      # registry shape - emitted as the registry's "helpers" section
      # (rakelib/registry.rake) so poetry check and the MCP server validate
      # these literals statically (the crash class: a helper-only literal
      # like align: :leading that no component contract covers, failing
      # only at render). Plain wrapper helpers need no entry here;
      # registry generation lists them name-only.
      HELPER_CONTRACTS = {
        "poetry_toast_trigger" => {
          "options" => [
            { "name" => "template", "type" => "string",
              "description" => "id of the <template> holding the rendered poetry_toast" },
            { "name" => "toaster", "type" => "string",
              "description" => "optional toaster region id - omit for the page's toaster" }
          ]
        },
        "poetry_optimistic_form" => {
          "yields" => "the form builder - form.optimistic_template authors the predicted " \
                      "turbo-stream(s); form.optimistic_hidden_field places the submitted value; " \
                      "every standard field helper works",
          "options" => [
            { "name" => "attribute_name", "type" => "symbol" },
            { "name" => "value", "type" => "object" }
          ]
        },
        "poetry_input_group_addon" => {
          "options" => [{ "name" => "align", "type" => "symbol", "default" => "inline-start",
                          "variants" => INPUT_GROUP_ALIGNS.map(&:to_s) }]
        },
        "poetry_input_group_button" => {
          "options" => [{ "name" => "size", "type" => "symbol", "default" => "xs",
                          "variants" => INPUT_GROUP_BUTTON_SIZES.map(&:to_s) }]
        }
      }.freeze

      # A window overlaid on the page for content that requires attention.
      #
      # @example A confirmation dialog
      #     poetry_dialog do |dialog|
      #       dialog.with_trigger(variant: :outline) { "Open" }
      #       dialog.with_title { "Are you sure?" }
      #       dialog.with_description { "This cannot be undone." }
      #     end
      # @see Poetry::Ui::Dialog::Component
      def poetry_dialog(**, &)
        render(Poetry::Ui::Dialog::Component.new(**), &)
      end

      # A dialog that slides in from a screen edge.
      #
      # @example
      #     poetry_sheet(side: :right) do |sheet|
      #       sheet.with_trigger { "Edit profile" }
      #       sheet.with_title { "Edit profile" }
      #       "Sheet body"
      #     end
      # @see Poetry::Ui::Sheet::Component
      def poetry_sheet(**, &)
        render(Poetry::Ui::Sheet::Component.new(**), &)
      end

      # A modal dialog that interrupts the user and expects a response.
      #
      # @example Destructive confirmation
      #     poetry_alert_dialog do |dialog|
      #       dialog.with_trigger(variant: :destructive) { "Delete project" }
      #       dialog.with_title { "Delete this project?" }
      #       dialog.with_description { "This cannot be undone." }
      #       dialog.with_cancel { "Cancel" }
      #       dialog.with_action(variant: :destructive) { "Delete" }
      #     end
      # @see Poetry::Ui::AlertDialog::Component
      def poetry_alert_dialog(**, &)
        render(Poetry::Ui::AlertDialog::Component.new(**), &)
      end

      # A form control for entering a single line of text.
      #
      # @example An email field
      #     poetry_input(type: "email", name: "email",
      #                                             placeholder: "you@example.com")
      # @see Poetry::Ui::Input::Component
      def poetry_input(**)
        render(Poetry::Ui::Input::Component.new(**))
      end

      # Input's multiline sibling - the value is the CONTENT (value:), not
      # a block; auto-grow is CSS (field-sizing-content), never a JS
      # autosizer.
      #
      # @example A free-text field
      #     poetry_textarea(name: "bio", rows: 4,
      #                                                placeholder: "Tell us about yourself")
      # @see Poetry::Ui::Textarea::Component
      def poetry_textarea(**)
        render(Poetry::Ui::Textarea::Component.new(**))
      end

      # Fixed-length code entry: ONE native input over aria-hidden cells
      # (paste/SMS-autofill/IME all native) - never per-cell inputs.
      #
      # @example
      #     poetry_input_otp(name: "code", length: 6, groups: [3, 3])
      # @see Poetry::Ui::InputOtp::Component
      def poetry_input_otp(**)
        render(Poetry::Ui::InputOtp::Component.new(**))
      end

      # An accessible caption bound to a form control.
      #
      # @example A label wired to its control
      #     poetry_label(for_id: "email") { "Email" }
      # @see Poetry::Ui::Label::Component
      def poetry_label(**, &)
        render(Poetry::Ui::Label::Component.new(**), &)
      end

      # The formatted number field: a formatted text input
      # over a hidden type=number that submits the raw value; steppers
      # with press-and-hold; ArrowUp/Down (Shift/Alt sizes) on the input.
      #
      # @example
      #     poetry_number_field(
      #       name: "quantity", value: 2, min: 0, label: "Quantity"
      #     )
      # @see Poetry::Ui::NumberField::Component
      def poetry_number_field(**)
        render(Poetry::Ui::NumberField::Component.new(**))
      end

      # The segmented date editor:
      # a native input type=date (ISO on the wire, native pickers with no
      # JS) enhanced into per-segment spinbutton editing.
      #
      # @example
      #     poetry_date_field(name: "event[on]", label: "Event date")
      # @see Poetry::Ui::DateField::Component
      def poetry_date_field(**)
        render(Poetry::Ui::DateField::Component.new(**))
      end

      # DateField at hour granularity: HH:MM[:SS] on the wire; the locale
      # decides 12- vs 24-hour editing (hour_cycle: pins it).
      #
      # @example
      #     poetry_time_field(
      #       name: "starts_at", label: "Start time", value: "09:30"
      #     )
      # @see Poetry::Ui::TimeField::Component
      def poetry_time_field(**)
        render(Poetry::Ui::TimeField::Component.new(**))
      end

      # A quantity within a known range (disk, seats, strength) - role
      # "meter progressbar" (the two-token fallback); never indeterminate.
      #
      # @example
      #     poetry_meter(value: 62, label: "Storage used")
      # @see Poetry::Ui::Meter::Component
      def poetry_meter(**)
        render(Poetry::Ui::Meter::Component.new(**))
      end

      # type=search on InputGroup chrome: Escape clears-then-dismisses,
      # focus-holding clear button, native WebKit affordances suppressed.
      #
      # @example
      #     poetry_search_field(name: "q", label: "Search", placeholder: "Search...")
      # @see Poetry::Ui::SearchField::Component
      def poetry_search_field(**)
        render(Poetry::Ui::SearchField::Component.new(**))
      end

      # Removable-chip collection (grid semantics, roving arrows, Delete
      # removal w/ focus recovery); name: serializes name[] per tag.
      #
      # @example Removable recipients that submit as recipients[]
      #     poetry_tag_group(label: "Recipients", name: "recipients") do |group|
      #       group.with_tag(value: "ada", label: "Ada")
      #       group.with_tag(value: "grace", label: "Grace")
      #     end
      # @see Poetry::Ui::TagGroup::Component
      def poetry_tag_group(**, &)
        render(Poetry::Ui::TagGroup::Component.new(**), &)
      end

      # Hierarchical expandable list (flat treegrid): items via the
      # nested with_item builder, expansion persisted by the host through
      # poetry:tree:toggle.
      #
      # @example
      #     <%= poetry_tree(label: "Files") do |tree| %>
      #       <% tree.with_item(text: "docs", value: "docs", expanded: true) do |docs| %>
      #         <% docs.with_item(text: "intro.md", value: "intro", href: "/docs/intro") %>
      #       <% end %>
      #     <% end %>
      # @see Poetry::Ui::Tree::Component
      def poetry_tree(**, &)
        render(Poetry::Ui::Tree::Component.new(**), &)
      end

      # Wraps a form control with its label, hint, and validation message.
      #
      # @example
      #     poetry_field(
      #       id: "email", label_text: "Email", hint: "We never share it."
      #     ) do |field|
      #       tag.input(type: "email", name: "email", **field.control_attributes)
      #     end
      # @see Poetry::Ui::Field::Component
      def poetry_field(**, &)
        render(Poetry::Ui::Field::Component.new(**), &)
      end

      # The Field family's group layer: a run of related fields inside a
      # real <fieldset>, named by legend: (a real <legend>).
      #
      # @example A named group of address fields
      #     poetry_fieldset(legend: "Shipping address") do
      #       # poetry_field_group with the fields
      #     end
      # @see Poetry::Ui::Fieldset::Component
      def poetry_fieldset(**, &)
        render(Poetry::Ui::Fieldset::Component.new(**), &)
      end

      # Stacks fields/fieldsets with the theme's rhythm; also the CSS
      # `@container` scope Field's orientation: :responsive measures against.
      #
      # @example Stacking fields with the theme's rhythm
      #     poetry_field_group do
      #       safe_join([
      #         poetry_field { ... },
      #         poetry_field_separator,
      #         poetry_field { ... }
      #       ])
      #     end
      # @see Poetry::Ui::FieldGroup::Component
      def poetry_field_group(**, &)
        render(Poetry::Ui::FieldGroup::Component.new(**), &)
      end

      # Divider between stacked fields; pass a block for the inline
      # caption form ("Or continue with").
      #
      # @example A captioned divider between stacked fields
      #     poetry_field_separator { "Or continue with" }
      # @see Poetry::Ui::FieldSeparator::Component
      def poetry_field_separator(**, &)
        render(Poetry::Ui::FieldSeparator::Component.new(**), &)
      end

      # Void control (no content block) - the label is EXTERNAL (Label/Field
      # for= the button id) or label: (the aria-label fallback).
      #
      # @example A form checkbox
      #     poetry_checkbox(name: "terms", label: "Accept terms")
      # @see Poetry::Ui::Checkbox::Component
      def poetry_checkbox(**)
        render(Poetry::Ui::Checkbox::Component.new(**))
      end

      # The select-all family (the APG mixed-state
      # parent): the wrapper carries the poetry--core--checkbox-group
      # controller; the parent checkbox fans out to every enabled item and
      # item toggles re-derive it (all -> checked, none -> unchecked,
      # some -> indeterminate).
      #
      # @example
      #   poetry_checkbox_group do
      #     poetry_checkbox_group_all(id: "all")
      #     poetry_checkbox_group_item(name: "ids[]", value: "1", id: "row-1")
      #   end
      # @see Poetry::Ui::Checkbox::Component
      def poetry_checkbox_group(**attrs, &block)
        # role=group makes the aria-labelledby/-describedby the FormBuilder
        # routes here real for AT - on a bare div they announce nothing.
        wiring = { role: "group", class: attrs.delete(:class),
                   data: { slot: "checkbox-group", controller: "poetry--core--checkbox-group",
                           action: "poetry:checkbox:change->poetry--core--checkbox-group#changed" } }
        content_tag(:div, (capture(&block) if block),
                    Poetry::Core::HTML::Attributes.merged(wiring, attrs))
      end

      # The group's parent checkbox (target: all) - checking it fans out.
      #
      # @example
      #   poetry_checkbox_group_all(id: "select-all")
      # @see Poetry::Ui::Checkbox::Component
      def poetry_checkbox_group_all(**attrs)
        data = { "poetry--core--checkbox-group-target": "all" }.merge(attrs.delete(:data) || {})
        render(Poetry::Ui::Checkbox::Component.new(**attrs, data: data))
      end

      # One member checkbox (target: item) - toggles re-derive the parent.
      #
      # @example
      #   poetry_checkbox_group_item(name: "ids[]", value: "1", checked: true)
      # @see Poetry::Ui::Checkbox::Component
      def poetry_checkbox_group_item(**attrs)
        data = { "poetry--core--checkbox-group-target": "item" }.merge(attrs.delete(:data) || {})
        render(Poetry::Ui::Checkbox::Component.new(**attrs, data: data))
      end

      # Read-only value + one copy affordance (API keys, install commands,
      # IDs); text_to_copy: overrides the clipboard when the display
      # truncates. Editable text is poetry_input; masked secrets are
      # poetry_sensitive_input.
      #
      # @example An install command with a copy button
      #     poetry_clipboard_text(value: "gem install poetry-ui",
      #                                                     label: "Install command")
      # @see Poetry::Ui::ClipboardText::Component
      def poetry_clipboard_text(**)
        render(Poetry::Ui::ClipboardText::Component.new(**))
      end

      # Server-rendered highlighted code panel (rouge, soft dependency):
      # language:, CSS-counter line_numbers:, highlight_lines:, and a
      # copy affordance reading the rendered code. Inline code stays
      # plain <code> typography.
      #
      # @example
      #     poetry_code_block(
      #       code: "puts \"hello\"", language: "ruby"
      #     )
      # @see Poetry::Ui::CodeBlock::Component
      def poetry_code_block(**)
        render(Poetry::Ui::CodeBlock::Component.new(**))
      end

      # Secret shown-on-demand (API keys, tokens): masked container is the
      # reveal button, blur/Escape/eye re-mask, copy: copies without
      # revealing. Plain passwords being SET (not shown) can stay a
      # poetry_input type: :password.
      #
      # @example An API key with copy-without-reveal
      #     poetry_sensitive_input(name: "api_key", label: "API key",
      #                                                      value: token, copy: true)
      # @see Poetry::Ui::SensitiveInput::Component
      def poetry_sensitive_input(**)
        render(Poetry::Ui::SensitiveInput::Component.new(**))
      end

      # Void control - instant-effect on/off (role=switch announces on/off);
      # values staged for submit belong to poetry_checkbox.
      #
      # @example A named setting switch
      #     poetry_switch(name: "notifications", checked: true,
      #                                              label: "Email notifications")
      # @see Poetry::Ui::Switch::Component
      def poetry_switch(**)
        render(Poetry::Ui::Switch::Component.new(**))
      end

      # One-question-at-a-time survey: a REAL form of fieldset items -
      # native radio/checkbox/text answers, validate-gated navigation.
      #
      # @example
      #     poetry_questionnaire(url: "/surveys") do |survey|
      #       survey.with_item(name: "mood", title: "How was your week?") do |item|
      #         item.with_choice(value: "good", label: "Good")
      #         item.with_choice(value: "bad", label: "Bad")
      #       end
      #     end
      # @see Poetry::Ui::Questionnaire::Component
      def poetry_questionnaire(**, &)
        render(Poetry::Ui::Questionnaire::Component.new(**), &)
      end

      # The exclusive-choice control: group.with_item(value:, label:) -
      # one hidden native radio per item (collection_radio_buttons-exact
      # serialization). The group MUST be labelled (label: or
      # aria-labelledby).
      #
      # @example
      #     poetry_radio_group(
      #       name: "plan", value: "monthly", label: "Billing plan"
      #     ) do |group|
      #       group.with_item(value: "monthly", label: "Monthly")
      #       group.with_item(value: "yearly", label: "Yearly")
      #     end
      # @see Poetry::Ui::RadioGroup::Component
      def poetry_radio_group(**, &)
        render(Poetry::Ui::RadioGroup::Component.new(**), &)
      end

      # Void control - numeric value (value:) or [low, high] range
      # (values:) on a continuous track; every thumb needs a distinct
      # accessible name (label:).
      #
      # @example
      #     poetry_slider(name: "volume", value: 50, label: "Volume")
      # @see Poetry::Ui::Slider::Component
      def poetry_slider(**)
        render(Poetry::Ui::Slider::Component.new(**))
      end

      # A chat message bubble aligned to its sender.
      #
      # @example An assistant reply
      #     poetry_bubble(variant: :secondary) { "Here's the summary." }
      # @see Poetry::Ui::Bubble::Component
      def poetry_bubble(**, &)
        render(Poetry::Ui::Bubble::Component.new(**), &)
      end

      # A styled wrapper stacking one sender's consecutive bubbles - a
      # dictionary element, not a component (a Bubble concern).
      #
      # @example
      #   <%= poetry_bubble_group do %>
      #     <%= poetry_bubble(variant: :sent) { "Hi!" } %>
      #     <%= poetry_bubble(variant: :sent) { "You there?" } %>
      #   <% end %>
      # @see Poetry::Ui::Bubble::Component
      def poetry_bubble_group(**attrs, &)
        poetry_chat_group(Poetry::Ui::Bubble::Style, "bubble-group", **attrs, &)
      end

      # Pressed-state button (aria-pressed) - UI state, NOT form data; the
      # content block is the icon/text (icon-only requires label:).
      #
      # @example An icon-only bookmark toggle
      #     poetry_toggle(label: "Bookmark", pressed: bookmarked?) do
      #       poetry_icon(name: :bookmark)
      #     end
      # @see Poetry::Ui::Toggle::Component
      def poetry_toggle(**, &)
        render(Poetry::Ui::Toggle::Component.new(**), &)
      end

      # A set of Toggle-styled items under one value machine + one roving
      # tab stop: group.with_item(value:, label:) { icon/text }.
      #
      # @example A text-alignment switcher
      #     poetry_toggle_group(value: "left", label: "Text alignment") do |group|
      #       group.with_item(value: "left", label: "Align left") { icon(:"align-left") }
      #       group.with_item(value: "center", label: "Align center") { icon(:"align-center") }
      #     end
      # @see Poetry::Ui::ToggleGroup::Component
      def poetry_toggle_group(**, &)
        render(Poetry::Ui::ToggleGroup::Component.new(**), &)
      end

      # A chat row pairing an author and avatar with message content.
      #
      # @example
      #     poetry_message do |message|
      #       message.with_avatar { "AI" }
      #       message.with_header { "Assistant" }
      #       tag.div("Here's the plan for today.")
      #     end
      # @see Poetry::Ui::Message::Component
      def poetry_message(**, &)
        render(Poetry::Ui::Message::Component.new(**), &)
      end

      # A styled wrapper stacking one sender's consecutive messages - a
      # dictionary element, not a component (a Message concern).
      #
      # @example
      #   <%= poetry_message_group do %>
      #     <%# consecutive poetry_message rows from one sender %>
      #   <% end %>
      # @see Poetry::Ui::Message::Component
      def poetry_message_group(**attrs, &)
        poetry_chat_group(Poetry::Ui::Message::Style, "message-group", **attrs, &)
      end

      # A transcript divider or inline status marker for chat UIs.
      #
      # @example
      #     poetry_marker(variant: :separator) { "Yesterday" }
      # @see Poetry::Ui::Marker::Component
      def poetry_marker(**, &)
        render(Poetry::Ui::Marker::Component.new(**), &)
      end

      # A file or image chip showing its name, type, and size.
      #
      # @example A finished upload
      #     poetry_attachment do |attachment|
      #       attachment.with_title { "quarterly-report.pdf" }
      #       attachment.with_description { "1.2 MB" }
      #     end
      # @see Poetry::Ui::Attachment::Component
      def poetry_attachment(**, &)
        render(Poetry::Ui::Attachment::Component.new(**), &)
      end

      # The horizontally-scrolling attachment rail (scroll-fade + snap).
      #
      # @example
      #   <%= poetry_attachment_group do %>
      #     <%# poetry_attachment chips %>
      #   <% end %>
      # @see Poetry::Ui::Attachment::Component
      def poetry_attachment_group(**attrs, &)
        poetry_chat_group(Poetry::Ui::Attachment::Style, "attachment-group", **attrs, &)
      end

      # A streaming-aware transcript that keeps the latest message in view.
      #
      # @example A chat transcript
      #     poetry_message_scroller(id: "chat") do
      #       # poetry_message_scroller_item rows
      #     end
      # @see Poetry::Ui::MessageScroller::Component
      def poetry_message_scroller(**, &)
        render(Poetry::Ui::MessageScroller::Component.new(**), &)
      end

      # One transcript row - the id is how anchoring and Turbo Streams
      # find it (data-message-id; anchor: pins the reading position).
      #
      # @example
      #   <%= poetry_message_scroller_item(id: message.id) do %>
      #     <%= poetry_message(author: "Ada") { message.body } %>
      #   <% end %>
      # @see Poetry::Ui::MessageScroller::Component
      def poetry_message_scroller_item(id:, anchor: false, **attrs, &)
        classes = [Poetry::Ui::MessageScroller::Style.css(:item), attrs.delete(:class)].compact.join(" ")
        # data-message-id is the anchoring/Turbo-Stream identity - RESERVED:
        # the id: argument wins over any caller spelling. Other caller data
        # keys (and stimulus wiring) ride along.
        attrs.delete("data-message-id")
        attrs.delete(:"data-message-id")
        data = (attrs.delete(:data) || {}).merge(slot: "message-scroller-item", "message-id": id)
        data[:"scroll-anchor"] = "true" if anchor
        tag.div(**Poetry::Core::HTML::Attributes.merged({ class: classes, data: data }, attrs)
                  .symbolize_keys, &)
      end

      # A brief, auto-dismissing notification message.
      #
      # @example An undo toast (persistent because it carries an action)
      #     poetry_toast(variant: :success) do |toast|
      #       toast.with_title { "Message archived" }
      #       toast.with_action { "Undo" }
      #     end
      # @see Poetry::Ui::Toast::Component
      def poetry_toast(**, &)
        render(Poetry::Ui::Toast::Component.new(**), &)
      end

      # The toast viewport - render ONCE in the application layout (it is
      # data-turbo-permanent; turbo_stream.poetry_toast appends into it).
      #
      # @example The flash -> toast mapping in the layout
      #     <%= poetry_toaster do %>
      #       <% flash.each do |kind, message| %>
      #         <%= poetry_toast(variant: kind.to_s == "alert" ? :destructive : :default) do |toast| %>
      #           <% toast.with_title { message } %>
      #         <% end %>
      #       <% end %>
      #     <% end %>
      # @see Poetry::Ui::Toaster::Component
      def poetry_toaster(**, &)
        render(Poetry::Ui::Toaster::Component.new(**), &)
      end

      # An interactive element that expands and collapses a section of
      # content.
      #
      # @example
      #     poetry_collapsible do |collapsible|
      #       collapsible.with_trigger { "Show details" }
      #       tag.div("Hidden until disclosed.")
      #     end
      # @see Poetry::Ui::Collapsible::Component
      def poetry_collapsible(**, &)
        render(Poetry::Ui::Collapsible::Component.new(**), &)
      end

      # A vertically stacked set of interactive headings that each reveal a
      # section of content.
      #
      # @example Single-open accordion with the first item expanded
      #     poetry_accordion(open: %w[a]) do |accordion|
      #       accordion.with_item(value: "a", title: "First") { "First panel" }
      #       accordion.with_item(value: "b", title: "Second") { "Second panel" }
      #     end
      # @see Poetry::Ui::Accordion::Component
      def poetry_accordion(**, &)
        render(Poetry::Ui::Accordion::Component.new(**), &)
      end

      # Rich floating content anchored to a trigger.
      #
      # @example
      #     poetry_popover do |popover|
      #       popover.with_trigger(variant: :outline) { "Open popover" }
      #       popover.with_title { "Dimensions" }
      #       tag.p("Set the dimensions for the layer.")
      #     end
      # @see Poetry::Ui::Popover::Component
      def poetry_popover(**, &)
        render(Poetry::Ui::Popover::Component.new(**), &)
      end

      # A floating label describing an element on hover or focus.
      #
      # @example A described icon button
      #     poetry_tooltip do |tooltip|
      #       tooltip.with_trigger(variant: :outline, size: :icon, label: "Print") do
      #         poetry_icon(name: :printer)
      #       end
      #       "Print the current page"
      #     end
      # @see Poetry::Ui::Tooltip::Component
      def poetry_tooltip(**, &)
        render(Poetry::Ui::Tooltip::Component.new(**), &)
      end

      # The tooltip delay/warm SCOPE - a config-carrying div, NOT a
      # controller (the DOM ancestor IS the shared delay scope; the tooltip
      # controller reads closest('[data-slot=tooltip-provider]') and keys
      # the module-level warm registry by it). Wrap control rows in ONE
      # provider so the warm grace makes the row feel continuous.
      #
      # @example
      #   <%= poetry_tooltip_provider(delay_duration: 300) do %>
      #     <%# tooltips inside share the delay + warm state %>
      #   <% end %>
      # @see Poetry::Ui::Tooltip::Component
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

      # A card that reveals preview content when its trigger is hovered.
      #
      # @example A profile preview behind a real link
      #     poetry_hover_card do |card|
      #       card.with_trigger(href: "/users/nextjs") { "@nextjs" }
      #       "Joined December 2021."
      #     end
      # @see Poetry::Ui::HoverCard::Component
      def poetry_hover_card(**, &)
        render(Poetry::Ui::HoverCard::Component.new(**), &)
      end

      # A menu of actions or options triggered by a button.
      #
      # @example A menu button with actions
      #     poetry_dropdown_menu do |menu|
      #       menu.with_trigger(variant: :outline) { "Open" }
      #       menu.with_item { "Rename" }
      #       menu.with_item(variant: :destructive) { "Delete" }
      #     end
      # @see Poetry::Ui::DropdownMenu::Component
      def poetry_dropdown_menu(**, &)
        render(Poetry::Ui::DropdownMenu::Component.new(**), &)
      end

      # The value-choosing listbox (options ARE values; actions belong to
      # poetry_dropdown_menu). Must be named: a Field label (id: +
      # label[for]) or aria-label. In forms, prefer f.poetry_select.
      #
      # @example A named form select
      #     poetry_select(name: "fruit", id: "fruit",
      #                                              placeholder: "Pick a fruit") do |select|
      #       select.with_item(value: "apple") { "Apple" }
      #       select.with_item(value: "banana") { "Banana" }
      #     end
      # @see Poetry::Ui::Select::Component
      def poetry_select(**, &)
        render(Poetry::Ui::Select::Component.new(**), &)
      end

      # The type-to-filter value picker (Select's shell x Command's
      # engine): options ARE values, committed to a hidden native select.
      # Must be named (Field label via id: or aria-label). In forms,
      # prefer f.poetry_combobox.
      #
      # @example
      #     poetry_combobox(name: "framework", "aria-label" => "Framework") do |combobox|
      #       combobox.with_item(value: "rails") { "Ruby on Rails" }
      #       combobox.with_item(value: "hanami") { "Hanami" }
      #     end
      # @see Poetry::Ui::Combobox::Component
      def poetry_combobox(**, &)
        render(Poetry::Ui::Combobox::Component.new(**), &)
      end

      # A menu of actions revealed by right-clicking an element.
      #
      # @example Right-click surface with actions
      #     poetry_context_menu do |menu|
      #       menu.with_trigger(tag: :div) { "Right-click this card" }
      #       menu.with_item { "Rename" }
      #       menu.with_item(variant: :destructive) { "Delete" }
      #     end
      # @see Poetry::Ui::ContextMenu::Component
      def poetry_context_menu(**, &)
        render(Poetry::Ui::ContextMenu::Component.new(**), &)
      end

      # The filterable command-palette listbox: items DO
      # things - picking a VALUE for a form is Combobox territory.
      #
      # @example
      #     poetry_command("aria-label": "Command menu") do |command|
      #       command.with_item(value: "new-file") { "New file" }
      #       command.with_item(value: "search") { "Search" }
      #     end
      # @see Poetry::Ui::Command::Component
      def poetry_command(**, &)
        render(Poetry::Ui::Command::Component.new(**), &)
      end

      # The ⌘K variant: a Command inside the Dialog chrome (sr-only
      # title/description) with the OPT-IN hotkey: global shortcut.
      #
      # @example
      #     poetry_command_dialog(hotkey: "meta+k") do |dialog|
      #       dialog.with_trigger(variant: :outline) { "Open palette" }
      #       dialog.with_item(value: "settings") { "Settings" }
      #     end
      # @see Poetry::Ui::Command::DialogComponent
      def poetry_command_dialog(**, &)
        render(Poetry::Ui::Command::DialogComponent.new(**), &)
      end

      # A horizontal bar of menus, like a desktop application menu.
      #
      # @example An application command bar
      #     poetry_menubar(label: "Application") do |bar|
      #       bar.with_menu do |menu|
      #         menu.with_trigger { "File" }
      #         menu.with_item(shortcut: "⌘N") { "New" }
      #         menu.with_separator
      #         menu.with_item { "Print..." }
      #       end
      #     end
      # @see Poetry::Ui::Menubar::Component
      def poetry_menubar(**, &)
        render(Poetry::Ui::Menubar::Component.new(**), &)
      end

      # The composed-DOM duplicate-id tripwire: a DEVELOPMENT
      # guard that scans the live page for duplicate [id] values after
      # every composition event (load, Turbo loads, frame loads, morphs,
      # stream insertions) and console-warns - the runtime complement to
      # poetry check's static stable-identity heuristics, and the only
      # check that sees real composition. Render in the development
      # layout's <head>; it emits nothing outside development unless
      # force: true (the dummy's test pages dogfood it that way).
      #
      # @example
      #   <%# in the development layout's <head> %>
      #   <%= poetry_id_integrity_script %>
      def poetry_id_integrity_script(force: false)
        return unless force || Rails.env.development?

        javascript_tag(<<~JS, type: "module", nonce: true)
          import { installPoetryIdIntegrityCheck } from "@poetry/controllers/helpers/id_integrity"
          installPoetryIdIntegrityCheck()
        JS
      end

      # The color-scheme bootstrap (the pothole other ports patch
      # into every host by hand): tokens ship `.dark` + `color-scheme`, but
      # WHEN `.dark` applies is the host's job - and it must happen before
      # first paint or every visit flashes light. Render inside <head>,
      # before the stylesheets. Also wires window.Poetry.colorScheme
      # (current/set/toggle/clear) for toggle controls; an unset preference
      # follows the OS and tracks its changes live. Full recipe:
      # the Theming guide, "Color scheme (dark mode)".
      #
      # @example
      #   <%# in the layout <head>, before the stylesheets %>
      #   <%= poetry_color_scheme_script %>
      def poetry_color_scheme_script
        javascript_tag(COLOR_SCHEME_JS, nonce: true)
      end

      # The inline bootstrap poetry_color_scheme_script emits: applies the
      # stored (or OS) scheme before first paint and wires
      # window.Poetry.colorScheme.
      COLOR_SCHEME_JS = <<~JS
        (() => {
          const KEY = "poetry-color-scheme";
          const media = window.matchMedia("(prefers-color-scheme: dark)");
          const stored = () => { try { return localStorage.getItem(KEY); } catch { return null; } };
          const current = () => stored() || (media.matches ? "dark" : "light");
          const apply = () => {
            const mode = current();
            document.documentElement.classList.toggle("dark", mode === "dark");
            document.documentElement.dispatchEvent(
              new CustomEvent("poetry:color-scheme", { bubbles: true, detail: { mode } })
            );
          };
          apply();
          media.addEventListener("change", () => { if (!stored()) apply(); });
          window.Poetry = window.Poetry || {};
          window.Poetry.colorScheme = {
            current,
            set(mode) {
              try { mode ? localStorage.setItem(KEY, mode) : localStorage.removeItem(KEY); } catch {}
              apply();
            },
            toggle() { this.set(current() === "dark" ? "light" : "dark"); },
            clear() { this.set(null); }
          };
        })();
      JS

      private

      # Auto-inject only when the caller supplied the pair AND didn't place
      # the field explicitly inside the block (the block is captured first,
      # so an explicit optimistic_hidden_field call wins).
      def optimistic_auto_inject?(form, attribute_name, value)
        attribute_name.present? &&
          !value.nil? &&
          !OptimisticFormBuilder::UNSET.equal?(value) &&
          !form.optimistic_hidden_field_rendered?
      end

      # The chat-set group wrappers are dictionary ELEMENTS, not components.
      def poetry_chat_group(style, slot, **attrs, &)
        classes = [style.css(slot.tr("-", "_").split("_").last.to_sym), attrs.delete(:class)].compact.join(" ")
        tag.div(**attrs.merge(class: classes, "data-slot" => slot), &)
      end
    end
  end
end
