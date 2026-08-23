# poetry blocks - vetted composed screens

Blocks are the DEFAULT starting point for a screen, not a
fallback: the MCP `compose` tool routes a brief to the right one
automatically (call it first); this file carries the same catalog
with full source. `bin/rails g poetry:block <name>` copies one
into app/views/blocks/ as source the app owns. Blocks carry the
composed patterns - containment, status color-coding, page
furniture, realistic content - so a screen starts composed, not
blank. The sample content is meant to be replaced.

## Block: Action bar (`action-bar`)

Bulk actions over a selectable table: a selection-driven floating bar with the live count, the actions, and clear - shown while rows are selected, Escape clears, focus never steals.
Composes: button, data_table, icon. Generate: `bin/rails g poetry:block action-bar`.
Source (adapt freely - the sample content is meant to be replaced):

<%# ActionBar is a BLOCK, not a component: the bar
    is plain markup wired to two small engines - the data_table's
    selectable: engine dispatches selection-change, and the bar's
    controller shows/hides on it, retains the last non-zero count while
    animating out, announces "Actions available." once per appearance,
    and Escape anywhere inside clears the selection. The wrapper div
    PAIRS them positionally (shared parent) - no id contract. Swap the
    sample actions for your bulk endpoints: the checkboxes are real form
    values (selected_ids[]), so a wrapping form_with posts them as-is. %>
<% invoice = Struct.new(:id, :number, :customer, :amount) %>
<% rows = local_assigns[:rows] || [
     invoice.new(1, "INV-001", "Acme", "$250.00"),
     invoice.new(2, "INV-002", "Globex", "$1,150.00"),
     invoice.new(3, "INV-003", "Initech", "$420.00")
   ] %>
<% state = Poetry::Ui::DataTable::State.from_params(params, sortable: %w[number customer]) %>
<div class="relative mx-auto max-w-3xl pb-16">
  <%= poetry_data_table(rows: rows, state: state, path: ->(p) { "?#{p.to_query}" },
                        caption: "Recent invoices.",
                        selectable: ->(row) { row.id }) do |table| %>
    <% table.with_column("Invoice", key: :number, sortable: true) { |row| row.number } %>
    <% table.with_column("Customer", key: :customer, sortable: true) { |row| row.customer } %>
    <% table.with_column("Amount", classes: "text-right") { |row| row.amount } %>
  <% end %>
  <div hidden
       data-controller="poetry--core--action-bar"
       data-poetry--core--action-bar-label-value="%{count} selected"
       data-available-label="Actions available."
       data-action="keydown->poetry--core--action-bar#keydown"
       data-slot="action-bar"
       class="absolute inset-x-8 bottom-2 z-10 mx-auto flex max-w-xl items-center gap-3 rounded-lg border bg-popover px-4 py-2 text-popover-foreground shadow-lg transition-[opacity,translate] data-open:translate-y-0 data-open:opacity-100 not-data-open:translate-y-2 not-data-open:opacity-0">
    <span data-slot="action-bar-count" class="text-sm font-medium tabular-nums"
          data-poetry--core--action-bar-target="count"></span>
    <span class="ms-auto flex items-center gap-2" data-slot="action-bar-actions" aria-label="Actions">
      <%= poetry_button(variant: :outline, size: :sm) { "Export" } %>
      <%= poetry_button(variant: :destructive, size: :sm) { "Archive" } %>
    </span>
    <%= poetry_button(variant: :ghost, size: :"icon-sm", label: "Clear selection",
                      "data-slot": "action-bar-clear",
                      data: { action: "click->poetry--core--action-bar#clear" }) do %>
      <%= poetry_icon(name: :x) %>
    <% end %>
  </div>
</div>

## Block: App shell (`app-shell`)

The frame every screen composes into: an icon-collapsible sidebar with grouped nav, badges and a user footer, plus a topbar with breadcrumb that answers the collapsed state, and a stat-card content grid.
Composes: avatar, breadcrumb, button, card, icon, separator, sidebar. Generate: `bin/rails g poetry:block app-shell`.
Source (adapt freely - the sample content is meant to be replaced):

<%= poetry_sidebar(collapsible: :icon) do |shell| %>
  <% shell.with_nav do %>
    <%= poetry_sidebar_header do %>
      <%# The collapse-aware header shape (a menu button, never a bare
          div): at icon width the button shrinks to the tile and the
          truncating spans disappear with it. %>
      <%= poetry_sidebar_menu do %>
        <%= poetry_sidebar_menu_item do %>
          <%= poetry_sidebar_menu_button(size: :lg) do %>
            <div class="flex aspect-square size-8 items-center justify-center rounded-lg bg-sidebar-primary text-sidebar-primary-foreground">
              <%= poetry_icon(name: :"audio-waveform", class: "size-4") %>
            </div>
            <div class="grid flex-1 text-left text-sm leading-tight">
              <span class="truncate font-semibold">Meridian</span>
              <span class="truncate text-xs">Operations</span>
            </div>
          <% end %>
        <% end %>
      <% end %>
    <% end %>
    <%= poetry_sidebar_content do %>
      <%= poetry_sidebar_group do %>
        <%= poetry_sidebar_group_label { "Platform" } %>
        <%= poetry_sidebar_menu do %>
          <%= poetry_sidebar_menu_item do %>
            <%= poetry_sidebar_menu_button(href: "/dashboard", active: true) do %>
              <%= poetry_icon(name: :"layout-dashboard") %><span>Dashboard</span>
            <% end %>
          <% end %>
          <%= poetry_sidebar_menu_item do %>
            <%= poetry_sidebar_menu_button(href: "/orders") do %>
              <%= poetry_icon(name: :package) %><span>Orders</span>
            <% end %>
            <%= poetry_sidebar_menu_badge do %>12<% end %>
          <% end %>
          <%= poetry_sidebar_menu_item do %>
            <%= poetry_sidebar_menu_button(href: "/customers") do %>
              <%= poetry_icon(name: :users) %><span>Customers</span>
            <% end %>
          <% end %>
        <% end %>
      <% end %>
      <%= poetry_sidebar_group do %>
        <%= poetry_sidebar_group_label { "Resources" } %>
        <%= poetry_sidebar_menu do %>
          <%= poetry_sidebar_menu_item do %>
            <%= poetry_sidebar_menu_button(href: "/docs") do %>
              <%= poetry_icon(name: :"book-open") %><span>Documentation</span>
            <% end %>
          <% end %>
          <%= poetry_sidebar_menu_item do %>
            <%= poetry_sidebar_menu_button(href: "/support") do %>
              <%= poetry_icon(name: :"life-buoy") %><span>Support</span>
            <% end %>
          <% end %>
        <% end %>
      <% end %>
    <% end %>
    <%= poetry_sidebar_footer do %>
      <%# The footer rides the same collapse-aware shape as the header: at
          icon width the menu button shrinks to the avatar tile and the
          truncating spans clip with it instead of spilling into the inset. %>
      <%= poetry_sidebar_menu do %>
        <%= poetry_sidebar_menu_item do %>
          <% profile = "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCA2NCA2NCI+PGRlZnM+PGxpbmVhckdyYWRpZW50IGlkPSJnIiB4MT0iMCIgeTE9IjAiIHgyPSIxIiB5Mj0iMSI+PHN0b3Agb2Zmc2V0PSIwIiBzdG9wLWNvbG9yPSIjNjM2NmYxIi8+PHN0b3Agb2Zmc2V0PSIuNTUiIHN0b3AtY29sb3I9IiM4YjVjZjYiLz48c3RvcCBvZmZzZXQ9IjEiIHN0b3AtY29sb3I9IiNlYzQ4OTkiLz48L2xpbmVhckdyYWRpZW50PjwvZGVmcz48cmVjdCB3aWR0aD0iNjQiIGhlaWdodD0iNjQiIGZpbGw9InVybCgjZykiLz48Y2lyY2xlIGN4PSIzMiIgY3k9IjI1IiByPSIxMCIgZmlsbD0iI2ZmZiIgb3BhY2l0eT0iLjkiLz48cGF0aCBkPSJNMTIgNjRjMi0xMyAxMC0xOSAyMC0xOXMxOCA2IDIwIDE5eiIgZmlsbD0iI2ZmZiIgb3BhY2l0eT0iLjkiLz48L3N2Zz4=" %>
          <%= poetry_sidebar_menu_button(size: :lg) do %>
            <%= poetry_avatar(src: profile, label: "Matt Solt", class: "size-8 rounded-lg") { "MS" } %>
            <div class="grid flex-1 text-left text-sm leading-tight">
              <span class="truncate font-semibold">Matt Solt</span>
              <span class="truncate text-xs">matt@roboruby.com</span>
            </div>
          <% end %>
        <% end %>
      <% end %>
    <% end %>
    <%= poetry_sidebar_rail %>
  <% end %>
  <% shell.with_inset do %>
    <header class="flex h-14 shrink-0 items-center gap-2 border-b px-4 transition-[height] group-has-data-[collapsible=icon]/sidebar-wrapper:h-12">
      <%= poetry_sidebar_trigger %>
      <%= poetry_separator(orientation: :vertical, class: "h-4") %>
      <%= poetry_breadcrumb do |crumb| %>
        <% crumb.with_item("Meridian", href: "/") %>
        <% crumb.with_item("Dashboard") %>
      <% end %>
    </header>
    <div class="flex flex-col gap-6 p-6">
      <div class="flex flex-wrap items-end justify-between gap-4">
        <div class="space-y-1">
          <h1 class="text-2xl font-semibold tracking-tight">Dashboard</h1>
          <p class="text-sm text-muted-foreground">Today across the Meridian workspace.</p>
        </div>
        <%= poetry_button(variant: :outline) do |button| %>
          <% button.with_leading { poetry_icon(name: :download) } %>
          Export
        <% end %>
      </div>
      <div class="grid gap-4 md:grid-cols-3">
        <%= poetry_card(title_tag: :h2) do |card| %>
          <% card.with_title { "Revenue" } %>
          <% card.with_description { "Last 30 days" } %>
          <div class="text-2xl font-semibold tabular-nums">$48,210</div>
          <p class="text-xs text-muted-foreground">+12.4% from the previous period</p>
        <% end %>
        <%= poetry_card(title_tag: :h2) do |card| %>
          <% card.with_title { "Open orders" } %>
          <% card.with_description { "Awaiting fulfillment" } %>
          <div class="text-2xl font-semibold tabular-nums">42</div>
          <p class="text-xs text-muted-foreground">12 due before Friday</p>
        <% end %>
        <%= poetry_card(title_tag: :h2) do |card| %>
          <% card.with_title { "On-time rate" } %>
          <% card.with_description { "Trailing quarter" } %>
          <div class="text-2xl font-semibold tabular-nums">98.2%</div>
          <p class="text-xs text-muted-foreground">Target is 97.5%</p>
        <% end %>
      </div>
      <%= poetry_card(title_tag: :h2) do |card| %>
        <% card.with_title { "Recent activity" } %>
        <% card.with_description { "The latest changes across orders and customers." } %>
        <ul class="space-y-3 text-sm">
          <li class="flex items-center justify-between gap-4">
            <span>ORD-1042 marked fulfilled by Matt</span>
            <span class="text-xs text-muted-foreground tabular-nums">2m ago</span>
          </li>
          <li class="flex items-center justify-between gap-4">
            <span>Northwind Traders added a shipping address</span>
            <span class="text-xs text-muted-foreground tabular-nums">18m ago</span>
          </li>
          <li class="flex items-center justify-between gap-4">
            <span>Refund approved for ORD-1040</span>
            <span class="text-xs text-muted-foreground tabular-nums">1h ago</span>
          </li>
        </ul>
      <% end %>
    </div>
  <% end %>
<% end %>

## Block: Data index (`data-index`)

A contained records screen: title bar with primary action, search-and-filter toolbar, status-badged table with a totals footer, and a result count paired with pagination.
Composes: badge, button, button_group, icon, input_group, label, native_select, pagination, table. Generate: `bin/rails g poetry:block data-index`.
Source (adapt freely - the sample content is meant to be replaced):

<section class="space-y-4">
  <div class="flex flex-wrap items-end justify-between gap-4">
    <div class="space-y-1">
      <h2 class="text-lg font-semibold tracking-tight">Orders</h2>
      <p class="text-sm text-muted-foreground">Fulfillment status across every open order.</p>
    </div>
    <%= poetry_button do |button| %>
      <% button.with_leading { poetry_icon(name: :plus) } %>
      New order
    <% end %>
  </div>
  <div class="flex flex-wrap items-center gap-3">
    <%= poetry_label(for_id: "orders-search", class: "sr-only") { "Search orders" } %>
    <%= poetry_input_group(class: "max-w-xs") do %>
      <%= poetry_input_group_addon do %>
        <%= poetry_icon(name: :search) %>
      <% end %>
      <%= poetry_input_group_input(id: "orders-search", name: "q", placeholder: "Search orders…") %>
    <% end %>
    <%= poetry_label(for_id: "orders-status", class: "sr-only") { "Filter by status" } %>
    <%= poetry_native_select(name: "status", id: "orders-status",
                             options: [["All statuses", "all"], ["Fulfilled", "fulfilled"],
                                       ["Processing", "processing"], ["Refunded", "refunded"]]) %>
    <%= poetry_button_group("aria-label": "Layout", class: "ml-auto") do %>
      <%= poetry_button(variant: :outline, size: :sm, "aria-pressed": "true") { "List" } %>
      <%= poetry_button(variant: :outline, size: :sm, "aria-pressed": "false") { "Board" } %>
    <% end %>
  </div>
  <div class="overflow-hidden rounded-lg border">
    <%= poetry_table do %>
      <%= poetry_table_caption(class: "sr-only") { "Open orders with customer, status, and total." } %>
      <%= poetry_table_header do %>
        <%= poetry_table_row do %>
          <%= poetry_table_head { "Order" } %>
          <%= poetry_table_head { "Customer" } %>
          <%= poetry_table_head { "Status" } %>
          <%= poetry_table_head(class: "text-right") { "Total" } %>
        <% end %>
      <% end %>
      <%= poetry_table_body do %>
        <%= poetry_table_row do %>
          <%= poetry_table_cell(class: "font-medium") { "ORD-1042" } %>
          <%= poetry_table_cell { "Northwind Traders" } %>
          <%= poetry_table_cell { poetry_badge(variant: :success) { "Fulfilled" } } %>
          <%= poetry_table_cell(class: "text-right tabular-nums") { "$1,250.00" } %>
        <% end %>
        <%= poetry_table_row do %>
          <%= poetry_table_cell(class: "font-medium") { "ORD-1041" } %>
          <%= poetry_table_cell { "Lumen Labs" } %>
          <%= poetry_table_cell { poetry_badge(variant: :warning) { "Processing" } } %>
          <%= poetry_table_cell(class: "text-right tabular-nums") { "$482.50" } %>
        <% end %>
        <%= poetry_table_row do %>
          <%= poetry_table_cell(class: "font-medium") { "ORD-1040" } %>
          <%= poetry_table_cell { "Aperture Optics" } %>
          <%= poetry_table_cell { poetry_badge(variant: :outline) { "Refunded" } } %>
          <%= poetry_table_cell(class: "text-right tabular-nums") { "$96.00" } %>
        <% end %>
        <%= poetry_table_row do %>
          <%= poetry_table_cell(class: "font-medium") { "ORD-1039" } %>
          <%= poetry_table_cell { "Gable & Sons" } %>
          <%= poetry_table_cell { poetry_badge(variant: :warning) { "Processing" } } %>
          <%= poetry_table_cell(class: "text-right tabular-nums") { "$2,040.00" } %>
        <% end %>
        <%= poetry_table_row do %>
          <%= poetry_table_cell(class: "font-medium") { "ORD-1038" } %>
          <%= poetry_table_cell { "Fern & Field" } %>
          <%= poetry_table_cell { poetry_badge(variant: :success) { "Fulfilled" } } %>
          <%= poetry_table_cell(class: "text-right tabular-nums") { "$318.75" } %>
        <% end %>
      <% end %>
      <%= poetry_table_footer do %>
        <%= poetry_table_row do %>
          <%= poetry_table_cell(colspan: 3) { "Total" } %>
          <%= poetry_table_cell(class: "text-right tabular-nums") { "$4,187.25" } %>
        <% end %>
      <% end %>
    <% end %>
  </div>
  <div class="flex flex-wrap items-center justify-between gap-4">
    <p class="text-sm text-muted-foreground">Showing 5 of 42 orders</p>
    <%= poetry_pagination(current: 3, total: 9, current_variant: :filled, path: ->(page) { "?page=#{page}" }) %>
  </div>
</section>

## Block: Destructive panel (`destructive-panel`)

A guarded destructive action: heading and consequences in plain language, a severity-tinted alert with the blast radius, and a cancel/confirm action pair.
Composes: alert, button, icon. Generate: `bin/rails g poetry:block destructive-panel`.
Source (adapt freely - the sample content is meant to be replaced):

<%# Page framing: the panel keeps its container + breathing room when it
    is the page's subject; drop the outer wrapper
    when composing into an already-padded frame. %>
<div class="mx-auto max-w-xl p-6">
  <section class="space-y-4 rounded-lg border border-destructive/50 p-6" aria-labelledby="destructive-panel-title">
    <div class="space-y-1">
      <h2 id="destructive-panel-title" class="text-base font-semibold">Revoke deploy token</h2>
      <p class="text-sm text-muted-foreground">The token stops working immediately. Three services signed their last deploy with it — their next runs will fail until a replacement is configured.</p>
    </div>
    <%# Icon + title only: an alert DESCRIPTION rides the destructive tint,
        which sits at 4.49:1 on white (just under the AA floor) -
        the blast radius lives in the AA-clean muted copy above instead. %>
    <%= poetry_alert(variant: :destructive) do |alert| %>
      <% alert.with_icon(name: "triangle-alert") %>
      <% alert.with_title { "This cannot be undone" } %>
    <% end %>
    <div class="flex items-center justify-end gap-2">
      <%= poetry_button(variant: :outline) { "Cancel" } %>
      <%= poetry_button(variant: :destructive) do |button| %>
        <% button.with_leading { poetry_icon(name: :trash) } %>
        Revoke token
      <% end %>
    </div>
  </section>
</div>

## Block: Page header (`page-header`)

The furniture a screen opens with: breadcrumb trail, page title with supporting description, and a right-aligned action group over a grounding rule.
Composes: breadcrumb, button, icon, separator. Generate: `bin/rails g poetry:block page-header`.
Source (adapt freely - the sample content is meant to be replaced):

<header class="flex flex-col gap-4">
  <%= poetry_breadcrumb do |crumb| %>
    <% crumb.with_item("Home", href: "/") %>
    <% crumb.with_item("Projects", href: "/projects") %>
    <% crumb.with_item("Atlas") %>
  <% end %>
  <div class="flex flex-wrap items-end justify-between gap-4">
    <div class="space-y-1">
      <h1 class="text-2xl font-semibold tracking-tight">Atlas</h1>
      <p class="text-sm text-muted-foreground">Shipping schedules, owners, and release health for the Atlas program.</p>
    </div>
    <div class="flex items-center gap-2">
      <%= poetry_button(variant: :outline) do |button| %>
        <% button.with_leading { poetry_icon(name: :download) } %>
        Export
      <% end %>
      <%= poetry_button do |button| %>
        <% button.with_leading { poetry_icon(name: :plus) } %>
        New project
      <% end %>
    </div>
  </div>
  <%= poetry_separator %>
</header>

## Block: Section card (`section-card`)

A contained content section: header row with title, supporting description and a status badge, body copy with a feature list, and a footer pairing meta text with a call-to-action.
Composes: badge, card, icon, link. Generate: `bin/rails g poetry:block section-card`.
Source (adapt freely - the sample content is meant to be replaced):

<%# Page framing: a section keeps its container + breathing room when it is
    the page's subject - a bare card at the viewport origin reads
    cramped. Drop the wrapper only when composing into an
    already-padded frame like the app-shell content area. %>
<div class="mx-auto max-w-md p-6">
  <%= poetry_card do |card| %>
    <% card.with_title { "Usage-based billing" } %>
    <% card.with_description { "Meter API calls and storage, invoiced monthly." } %>
    <% card.with_action do %>
      <%= poetry_badge(variant: :secondary) { "Beta" } %>
    <% end %>
    <% card.with_footer do %>
      <div class="flex w-full items-center justify-between gap-4">
        <span class="text-xs text-muted-foreground">Updated 2 days ago</span>
        <%# The CTA reads as interactive: always-underlined with a
            trailing arrow - the affordance that keeps it from reading
            as plain text. %>
        <%= poetry_link(href: "/docs/billing", underline: :always, class: "inline-flex items-center gap-1") do %>
          Learn more <%= poetry_icon(name: :"arrow-right", class: "size-3.5") %>
        <% end %>
      </div>
    <% end %>
    <div class="space-y-3 text-sm">
      <p>Pay for what the workspace actually uses. Metering runs hourly and the invoice line items match the usage dashboard.</p>
      <ul class="space-y-2">
        <li class="flex items-center gap-2">
          <%= poetry_icon(name: :check, class: "size-4 text-muted-foreground") %>
          <span>Per-request API metering</span>
        </li>
        <li class="flex items-center gap-2">
          <%= poetry_icon(name: :check, class: "size-4 text-muted-foreground") %>
          <span>Storage billed by the gigabyte-hour</span>
        </li>
        <li class="flex items-center gap-2">
          <%= poetry_icon(name: :check, class: "size-4 text-muted-foreground") %>
          <span>Spend alerts before every threshold</span>
        </li>
      </ul>
    </div>
  <% end %>
</div>

## Block: Stepper (`stepper`)

A multi-step flow header: numbered step indicators with connectors and completed/current/upcoming states over the current step's panel with back/continue actions.
Composes: button, card, icon. Generate: `bin/rails g poetry:block stepper`.
Source (adapt freely - the sample content is meant to be replaced):

<%# Stepper is a BLOCK, not a component: neither shadcn nor Base UI
    ships one, so the pattern lives here as copy-in source - adapt the
    steps freely; nothing hides behind an API. The server owns step state:
    pass step: as a local, or let it ride ?step= - Back/Continue are plain
    links that re-render, and completed steps are links back. In a real
    flow, swap the query param for your wizard's own routes/model state
    and the final action for a form submit. %>
<% steps = ["Shipping", "Payment", "Review"] %>
<% step = (local_assigns[:step] || params[:step] || 2).to_i.clamp(1, steps.length) %>
<% panels = {
     1 => ["Shipping", "Step 1 of 3 - where this order lands.",
           "Address fields mount here; this panel is the step's content slot."],
     2 => ["Payment", "Step 2 of 3 - how this order gets paid.",
           "Card details are collected by the payment element that mounts here; this panel is the step's content slot."],
     3 => ["Review", "Step 3 of 3 - confirm and place the order.",
           "The order summary renders here - line items, shipping choice, and the charge that Place order will submit."]
   } %>
<% title, description, body = panels.fetch(step) %>
<div class="mx-auto max-w-2xl p-6">
  <nav aria-label="Progress">
    <ol class="flex items-center gap-3">
      <% steps.each_with_index do |label, index| %>
        <% number = index + 1 %>
        <% unless number == 1 %>
          <li aria-hidden="true" class="h-px min-w-8 flex-1 <%= number <= step ? "bg-primary" : "bg-border" %>"></li>
        <% end %>
        <% if number < step %>
          <%# Completed: filled indicator with a check, revisitable. %>
          <li class="flex items-center">
            <a href="?step=<%= number %>" class="flex items-center gap-3 rounded-md outline-none focus-visible:ring-2 focus-visible:ring-ring">
              <span class="flex size-8 items-center justify-center rounded-full bg-primary text-primary-foreground">
                <%= poetry_icon(name: :check, class: "size-4", label: "Completed") %>
              </span>
              <span class="text-sm font-medium"><%= label %></span>
            </a>
          </li>
        <% elsif number == step %>
          <%# Current: outlined in primary, named by aria-current. %>
          <li aria-current="step" class="flex items-center gap-3">
            <span class="flex size-8 items-center justify-center rounded-full border-2 border-primary text-sm font-semibold text-primary"><%= number %></span>
            <span class="text-sm font-medium"><%= label %></span>
          </li>
        <% else %>
          <%# Upcoming: muted and inert until reached. %>
          <li class="flex items-center gap-3">
            <span class="flex size-8 items-center justify-center rounded-full border border-border text-sm text-muted-foreground"><%= number %></span>
            <span class="text-sm text-muted-foreground"><%= label %></span>
          </li>
        <% end %>
      <% end %>
    </ol>
  </nav>

  <div class="mt-6">
    <%= poetry_card do |card| %>
      <% card.with_title { title } %>
      <% card.with_description { description } %>
      <div class="space-y-4 text-sm">
        <p><%= body %></p>
      </div>
      <% card.with_footer do %>
        <div class="flex w-full items-center justify-between">
          <% if step > 1 %>
            <%= poetry_button(tag: :a, href: "?step=#{step - 1}", variant: :outline) { "Back" } %>
          <% else %>
            <span></span>
          <% end %>
          <% if step < steps.length %>
            <%= poetry_button(tag: :a, href: "?step=#{step + 1}") { "Continue to #{steps[step].downcase}" } %>
          <% else %>
            <%# The terminal action: wire this to your submit. %>
            <%= poetry_button { "Place order" } %>
          <% end %>
        </div>
      <% end %>
    <% end %>
  </div>
</div>

## Block: Top nav (`top-nav`)

A site navigation bar: brand mark, a products dropdown of rich title-and-description links, direct destinations, and the log-in / sign-up action pair.
Composes: button, icon, link, navigation_menu. Generate: `bin/rails g poetry:block top-nav`.
Source (adapt freely - the sample content is meant to be replaced):

<header class="w-full border-b">
  <div class="mx-auto flex h-14 max-w-5xl items-center justify-between gap-6 px-6">
    <%= poetry_link(href: "/", underline: :none, class: "inline-flex items-center gap-2 text-sm font-semibold") do %>
      <%= poetry_icon(name: :"audio-waveform", class: "size-4") %> Meridian
    <% end %>
    <%= poetry_navigation_menu(label: "Main", viewport: true) do |nav| %>
      <% nav.with_item("Products", value: "products") do %>
        <div class="grid w-96 grid-cols-2 gap-1 p-2">
          <%= poetry_navigation_menu_link(href: "/products/orders") do %>
            <div class="space-y-0.5">
              <div class="text-sm font-medium">Orders</div>
              <p class="text-xs text-muted-foreground">Fulfillment from checkout to doorstep.</p>
            </div>
          <% end %>
          <%= poetry_navigation_menu_link(href: "/products/customers") do %>
            <div class="space-y-0.5">
              <div class="text-sm font-medium">Customers</div>
              <p class="text-xs text-muted-foreground">Profiles, segments, and lifetime history.</p>
            </div>
          <% end %>
          <%= poetry_navigation_menu_link(href: "/products/analytics") do %>
            <div class="space-y-0.5">
              <div class="text-sm font-medium">Analytics</div>
              <p class="text-xs text-muted-foreground">Live dashboards over every workspace event.</p>
            </div>
          <% end %>
          <%= poetry_navigation_menu_link(href: "/products/automations") do %>
            <div class="space-y-0.5">
              <div class="text-sm font-medium">Automations</div>
              <p class="text-xs text-muted-foreground">Workflows that run while the team sleeps.</p>
            </div>
          <% end %>
        </div>
      <% end %>
      <% nav.with_link("Pricing", href: "/pricing") %>
      <% nav.with_link("Docs", href: "/docs") %>
    <% end %>
    <div class="flex items-center gap-2">
      <%= poetry_button(variant: :ghost, size: :sm, tag: :a, href: "/login") { "Log in" } %>
      <%= poetry_button(size: :sm, tag: :a, href: "/signup") { "Sign up" } %>
    </div>
  </div>
</header>

