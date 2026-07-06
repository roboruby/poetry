# frozen_string_literal: true

# N12 W2 mira plan ("compact interfaces") for write_theme.rb. The deepest
# density cut of the trio: h-7 buttons, text-xs/relaxed body type,
# 0.625rem badge/xs type, boxed accordion root (the cn-accordion hook),
# min-h-7 menu items. Judged notes: the floating before:-frame drawer is
# DEFERRED (poetry-own drawer geometry keeps the edge-attached idiom -
# direction rules cannot go empty; ledgered like the calendar cell
# density); accordion trigger gains poetry's focus-visible cluster
# (upstream mira ships none - keyboard focus must stay visible
# posture); input-group-button-size-sm targets a size poetry's API does
# not ship - dropped, ledgered.

# NOTE: the shipped themes/mira.css has been hand-edited since generation
# (bang audit, thin-body fixes, axe AA holds, W2 side-move consumers) - the
# fragment is canon; write_theme.rb refuses to regenerate over it.

BACKDROP = "backdrop:bg-black/10 supports-backdrop-filter:backdrop:backdrop-blur-xs"

PLAN = {
  # --- alert: poetry's 0-col grid idiom carries; mira skin lands on it ---
  "cn-alert" =>
    "grid grid-cols-[0_1fr] items-start gap-0.5 rounded-lg border px-2 py-1.5 text-left text-xs/relaxed " \
    "has-data-[slot=alert-action]:relative has-data-[slot=alert-action]:pr-18 " \
    "has-[>svg]:grid-cols-[auto_1fr] has-[>svg]:gap-x-1.5 " \
    "[&>svg]:size-3.5 [&>svg]:translate-y-0.5 [&>svg]:text-current",
  "cn-alert-title" => "col-start-2 font-medium",
  "cn-alert-description" =>
    "col-start-2 text-xs/relaxed text-muted-foreground text-balance md:text-pretty [&_p:not(:last-child)]:mb-4",

  # --- alert dialog -------------------------------------------------------
  "cn-alert-dialog-content" =>
    "w-full max-w-[calc(100%-2rem)] bg-popover text-popover-foreground ring-foreground/10 gap-3 " \
    "rounded-xl p-4 ring-1 duration-100 data-[size=default]:max-w-xs data-[size=sm]:max-w-64 " \
    "data-[size=default]:sm:max-w-sm #{BACKDROP} data-open:animate-in data-open:fade-in-0 " \
    "data-open:zoom-in-95",
  "cn-alert-dialog-header" => "gap-1",
  "cn-alert-dialog-media" => :default,
  "cn-alert-dialog-title" => "text-sm font-medium",
  # (cn-alert-dialog-footer: mira does not band it - inherits default's gap-2)

  # --- accordion: the boxed root (the W2 hook mira/rhea exist for);
  #     poetry focus cluster added (upstream ships no focus-visible) ------
  "cn-accordion" => "w-full overflow-hidden rounded-md border",
  "cn-accordion-trigger" =>
    { base: :upstream,
      drop: %w[**:data-[slot=accordion-trigger-icon]:text-muted-foreground
               **:data-[slot=accordion-trigger-icon]:ml-auto
               **:data-[slot=accordion-trigger-icon]:size-4],
      add: %w[focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50] },
  "cn-accordion-trigger-icon" => "ml-auto size-4 text-muted-foreground",

  # --- kept-default (poetry anatomy / continuity; see ledger) ------------
  "cn-avatar-badge" => :default,
  "cn-button-group-orientation-horizontal" => :default,
  "cn-button-group-orientation-vertical" => :default,
  "cn-calendar" => :default, # poetry-own engine; mira's --cell-size 6 deferred (ledger)
  "cn-combobox-trigger" => :default,
  "cn-drawer-swipe-handle" => :default,
  "cn-switch-thumb" => :default,
  "cn-tabs-trigger" => :default,

  # --- buttons: mira sizes + the >svg:first/last-child icon-side twins ---
  "cn-button-size-default" =>
    "h-7 gap-1 px-2 text-xs/relaxed has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 " \
    "has-[>svg:first-child]:pl-1.5 has-[>svg:last-child]:pr-1.5 [&_svg:not([class*='size-'])]:size-3.5",
  "cn-button-size-xs" =>
    "h-5 gap-1 rounded-sm px-2 text-[0.625rem] has-data-[icon=inline-end]:pr-1.5 " \
    "has-data-[icon=inline-start]:pl-1.5 " \
    "has-[>svg:first-child]:pl-1.5 has-[>svg:last-child]:pr-1.5 [&_svg:not([class*='size-'])]:size-2.5",
  "cn-button-size-sm" =>
    "h-6 gap-1 px-2 text-xs/relaxed has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 " \
    "has-[>svg:first-child]:pl-1.5 has-[>svg:last-child]:pr-1.5 [&_svg:not([class*='size-'])]:size-3",
  "cn-button-size-lg" =>
    "h-8 gap-1 px-2.5 text-xs/relaxed has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2 " \
    "has-[>svg:first-child]:pl-2 has-[>svg:last-child]:pr-2 [&_svg:not([class*='size-'])]:size-4",

  # --- soft destructive, AA-held (posture) --------------------------
  "cn-button-variant-destructive" =>
    "bg-destructive/10 hover:bg-destructive/20 focus-visible:ring-destructive/20 " \
    "dark:focus-visible:ring-destructive/40 dark:bg-destructive/20 " \
    "text-[oklch(from_var(--destructive)_calc(l*0.85)_c_h)] dark:text-destructive " \
    "focus-visible:border-destructive/40 dark:hover:bg-destructive/30",
  "cn-badge-variant-destructive" =>
    "bg-destructive/10 [a]:hover:bg-destructive/20 focus-visible:ring-destructive/20 " \
    "dark:focus-visible:ring-destructive/40 " \
    "text-[oklch(from_var(--destructive)_calc(l*0.85)_c_h)] dark:text-destructive " \
    "dark:bg-destructive/20",

  # --- badge: mira micro pill; svg-size bang stripped (policy) -----------
  "cn-badge" =>
    "h-5 gap-1 rounded-full border border-transparent px-2 py-0.5 text-[0.625rem] font-medium " \
    "transition-all has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 " \
    "has-[>svg:first-child]:pl-1.5 has-[>svg:last-child]:pr-1.5 [&>svg]:size-2.5",

  "cn-checkbox" => { base: :upstream, drop: %w[group-has-disabled/field:opacity-50] },

  # --- command: mira's flat search row; poetry keeps structural gap +
  #     placeholder color (anatomy needs) ---------------------------------
  "cn-command-input-wrapper" => "gap-2 p-1 pb-0",
  "cn-command-input" => "w-full bg-transparent text-xs/relaxed placeholder:text-muted-foreground",
  "cn-command-group" =>
    { base: :upstream, drop: %w[**:[[cmdk-group-heading]]:text-muted-foreground **:[[cmdk-group-heading]]:px-2.5
                                **:[[cmdk-group-heading]]:py-1.5 **:[[cmdk-group-heading]]:text-xs
                                **:[[cmdk-group-heading]]:font-medium] },

  # --- dialog / sheet / sidebar-mobile ------------------------------------
  "cn-dialog-content" =>
    "w-full max-w-[calc(100%-2rem)] bg-popover text-popover-foreground ring-foreground/10 gap-4 " \
    "rounded-xl p-4 text-xs/relaxed ring-1 duration-100 sm:max-w-sm #{BACKDROP} data-open:animate-in " \
    "data-open:fade-in-0 data-open:zoom-in-95",
  "cn-sheet-content" =>
    "m-0 w-full bg-popover text-popover-foreground text-xs/relaxed bg-clip-padding shadow-lg " \
    "transition duration-200 ease-in-out data-open:animate-in data-closed:animate-out #{BACKDROP}",
  "cn-sidebar-mobile" =>
    "bg-sidebar p-0 text-sidebar-foreground shadow-lg transition duration-200 ease-in-out " \
    "data-open:animate-in data-closed:animate-out #{BACKDROP}",

  # --- drawer: edge-attached idiom kept; the before:-frame is deferred ---
  "cn-drawer-content" => "bg-popover text-xs/relaxed text-popover-foreground",
  "cn-drawer-header" => "gap-1 p-4 md:text-left",
  "cn-drawer-footer" => :default,

  # --- menus ---------------------------------------------------------------
  "cn-dropdown-menu-sub-trigger" =>
    { base: :upstream, add: %w[data-popup-open:bg-accent data-popup-open:text-accent-foreground] },
  "cn-context-menu-sub-trigger" =>
    { base: :upstream, add: %w[data-popup-open:bg-accent data-popup-open:text-accent-foreground] },
  "cn-menubar-sub-trigger" =>
    { base: :upstream, add: %w[data-popup-open:bg-accent data-popup-open:text-accent-foreground] },
  "cn-context-menu-subcontent" => :upstream_sub_content,
  "cn-menubar-item-indicator" => "left-2 size-4 [&_svg:not([class*='size-'])]:size-4",

  "cn-combobox-content" =>
    "bg-popover dark:bg-popover text-popover-foreground ring-foreground/10 max-h-72 min-w-32 " \
    "overflow-hidden rounded-lg p-0 shadow-md ring-1 duration-100 data-open:animate-in " \
    "data-open:fade-in-0 data-open:zoom-in-95 data-closed:animate-out data-closed:fade-out-0 " \
    "data-closed:zoom-out-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 " \
    "data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2",

  "cn-radio-group-indicator-icon" => "size-2 fill-primary-foreground",

  # --- vocabulary translations -------------------------------------------
  "cn-slider" => { base: :upstream, sub: { "data-vertical:min-h-40" => "data-[orientation=vertical]:min-h-40" } },
  "cn-slider-track" =>
    { base: :upstream, sub: {
      "data-horizontal:h-1" => "data-[orientation=horizontal]:h-1",
      "data-horizontal:w-full" => "data-[orientation=horizontal]:w-full",
      "data-vertical:h-full" => "data-[orientation=vertical]:h-full",
      "data-vertical:w-1" => "data-[orientation=vertical]:w-1"
    } },
  "cn-table-row" =>
    "border-b transition-colors hover:bg-muted/50 has-aria-expanded:bg-muted/50 data-selected:bg-muted",

  # --- toggle group: per-item translation; mira segments round md --------
  "cn-toggle-group-item" =>
    "data-[spacing=0]:px-2 data-[spacing=0]:has-data-[icon=inline-end]:pr-1.5 " \
    "data-[spacing=0]:has-data-[icon=inline-start]:pl-1.5 " \
    "data-[spacing=0]:rounded-none " \
    "data-[spacing=0]:first:rounded-l-md data-[spacing=0]:last:rounded-r-md",

  "cn-toggle-size-default" =>
    "h-7 min-w-7 px-2 has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 " \
    "has-[>svg:first-child]:pl-1.5 has-[>svg:last-child]:pr-1.5",
  "cn-toggle-size-sm" =>
    "h-6 min-w-6 rounded-[min(var(--radius-md),8px)] px-2 text-[0.625rem] " \
    "has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 " \
    "has-[>svg:first-child]:pl-1.5 has-[>svg:last-child]:pr-1.5 [&_svg:not([class*='size-'])]:size-3",
  "cn-toggle-size-lg" =>
    "h-8 min-w-8 px-2.5 has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2 " \
    "has-[>svg:first-child]:pl-2 has-[>svg:last-child]:pr-2",

  "cn-tooltip-arrow" => "size-2.5 rounded-[2px]", # translate lives inline (spelling twin)

  "cn-attachment-media" =>
    { base: :upstream, sub: { "group-data-[orientation=vertical]/attachment:*:data-[slot=spinner]:size-6!" =>
                              "group-data-[orientation=vertical]/attachment:*:data-[slot=spinner]:size-6" } },

  # --- poetry-own toast family: upstream's rule is a delta over its own
  #     sonner base (mira keeps the default radius) - full body kept ------
  "cn-toast" => :default
}.freeze

HEADER = <<~CSS
  /* poetry mira theme (N12 W2) - upstream style-mira.css ported onto the
   * cn-* layer (pinned clone d0fae528). Same contract as default.css:
   * imported layer(base); bare selectors while installs carry ONE theme;
   * rule order per component = base < elements < variants < compounds;
   * split-side, no-empty-rules and cross-component-last rules apply.
   *
   * Port disciplines identical to vega (see the N12 plan note close-out +
   * docs/mira-port-ledger.txt): verbatim where poetry speaks the
   * vocabulary; data-vertical -> data-[orientation=*]; overlays ->
   * native-dialog backdrop:*; upstream ! stripped except the sidebar
   * collapse geometry; icon paddings ship upstream's has-data-[icon=*]
   * (inert) plus working >svg:first/last-child twins; soft destructive
   * holds AA via relative-oklch light-mode darkening (posture).
   * Mira-judged: boxed accordion root (the W2 hook); accordion trigger
   * carries poetry's focus-visible cluster (upstream ships none); the
   * floating before:-frame drawer is deferred (edge-attached idiom kept,
   * ledgered); input-group-button-size-sm dropped (no poetry sm size);
   * calendar cell density (--cell-size 6) deferred.
   */
CSS
