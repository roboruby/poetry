# frozen_string_literal: true

# N12 W2 nova plan ("reduced padding and margins") for write_theme.rb.
# Derived from the vega PLAN structure (W1) + report-nova.txt; every
# divergence from mechanical translation is a judged entry here.
# Theme character: vega's neutral ring-panel language at reduced heights
# (h-8 buttons), tighter paddings (p-4 dialogs), sm:max-w-sm dialogs, and
# the banded alert-dialog footer (the W2 hook nova exists for).

BACKDROP = "backdrop:bg-black/10 supports-backdrop-filter:backdrop:backdrop-blur-xs"

PLAN = {
  # --- alert: poetry's 0-col grid idiom carries; nova skin lands on it ----
  "cn-alert" =>
    "grid grid-cols-[0_1fr] items-start gap-0.5 rounded-lg border px-2.5 py-2 text-left text-sm " \
    "has-data-[slot=alert-action]:relative has-data-[slot=alert-action]:pr-18 " \
    "has-[>svg]:grid-cols-[auto_1fr] has-[>svg]:gap-x-2 " \
    "[&>svg]:size-4 [&>svg]:translate-y-0.5 [&>svg]:text-current",
  "cn-alert-title" => "col-start-2 font-medium",
  "cn-alert-description" =>
    "col-start-2 text-sm text-muted-foreground text-balance md:text-pretty [&_p:not(:last-child)]:mb-4",

  # --- alert dialog: native <dialog> (backdrop:*), server-side branches --
  "cn-alert-dialog-content" =>
    "w-full max-w-[calc(100%-2rem)] bg-popover text-popover-foreground ring-foreground/10 gap-4 " \
    "rounded-xl p-4 ring-1 duration-100 data-[size=default]:max-w-xs data-[size=sm]:max-w-xs " \
    "data-[size=default]:sm:max-w-sm #{BACKDROP} data-open:animate-in data-open:fade-in-0 " \
    "data-open:zoom-in-95",
  "cn-alert-dialog-header" => "gap-1.5",
  "cn-alert-dialog-media" => :default,
  "cn-alert-dialog-title" => "text-base font-medium",
  # The W2 hook: nova's banded footer (gap-2 continuity from the roster
  # landing; -mx-4/-mb-4 negate the content's p-4).
  "cn-alert-dialog-footer" => "gap-2 bg-muted/50 -mx-4 -mb-4 rounded-b-xl border-t p-4",

  # --- accordion: icon styling lives on poetry's own icon hook -----------
  "cn-accordion-trigger" =>
    { base: :upstream, drop: %w[**:data-[slot=accordion-trigger-icon]:text-muted-foreground
                                **:data-[slot=accordion-trigger-icon]:ml-auto
                                **:data-[slot=accordion-trigger-icon]:size-4] },
  "cn-accordion-trigger-icon" => "ml-auto size-4 text-muted-foreground",

  # --- kept-default (poetry anatomy / continuity; see ledger) ------------
  "cn-avatar-badge" => :default,
  "cn-button-group-orientation-horizontal" => :default,
  "cn-button-group-orientation-vertical" => :default,
  "cn-calendar" => :default, # poetry-own engine; nova's --cell-size 7 deferred (ledger)
  "cn-combobox-trigger" => :default,
  "cn-drawer-swipe-handle" => :default,
  "cn-switch-thumb" => :default,
  "cn-tabs-trigger" => :default,

  # --- buttons: nova sizes + the >svg:first/last-child icon-side twins ---
  "cn-button-size-default" =>
    "h-8 gap-1.5 px-2.5 has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2 " \
    "has-[>svg:first-child]:pl-2 has-[>svg:last-child]:pr-2",
  "cn-button-size-xs" =>
    "h-6 gap-1 rounded-[min(var(--radius-md),10px)] px-2 text-xs in-data-[slot=button-group]:rounded-lg " \
    "has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 " \
    "has-[>svg:first-child]:pl-1.5 has-[>svg:last-child]:pr-1.5 [&_svg:not([class*='size-'])]:size-3",
  "cn-button-size-sm" =>
    "h-7 gap-1 rounded-[min(var(--radius-md),12px)] px-2.5 text-[0.8rem] " \
    "in-data-[slot=button-group]:rounded-lg " \
    "has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 " \
    "has-[>svg:first-child]:pl-1.5 has-[>svg:last-child]:pr-1.5 [&_svg:not([class*='size-'])]:size-3.5",
  "cn-button-size-lg" =>
    "h-9 gap-1.5 px-2.5 has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2 " \
    "has-[>svg:first-child]:pl-2 has-[>svg:last-child]:pr-2",

  # --- soft destructive, AA-held (light darkens text via relative oklch,
  # dark restores the token) - documented deviation posture ----
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

  # --- badge: nova pill; svg-size bang stripped (policy) -----------------
  "cn-badge" =>
    "h-5 gap-1 rounded-4xl border border-transparent px-2 py-0.5 text-xs font-medium transition-all " \
    "has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 " \
    "has-[>svg:first-child]:pl-1.5 has-[>svg:last-child]:pr-1.5 [&>svg]:size-3",

  "cn-checkbox" => { base: :upstream, drop: %w[group-has-disabled/field:opacity-50] },

  # --- command: nova's flat search row (padding-only wrapper); poetry
  #     keeps structural gap + placeholder color (anatomy needs) ----------
  "cn-command" => { base: :upstream, sub: { "rounded-xl!" => "rounded-xl" } },
  "cn-command-input-wrapper" => "gap-2 p-1 pb-0",
  "cn-command-input" => "w-full bg-transparent text-sm placeholder:text-muted-foreground",
  "cn-command-item" =>
    { base: :upstream,
      sub: { "in-data-[slot=dialog-content]:rounded-lg!" => "in-data-[slot=dialog-content]:rounded-lg" } },
  "cn-command-group" =>
    { base: :upstream, drop: %w[**:[[cmdk-group-heading]]:text-muted-foreground **:[[cmdk-group-heading]]:px-2
                                **:[[cmdk-group-heading]]:py-1.5 **:[[cmdk-group-heading]]:text-xs
                                **:[[cmdk-group-heading]]:font-medium] },

  # --- dialog / sheet / sidebar-mobile: native-dialog mechanism residue --
  "cn-dialog-content" =>
    "w-full max-w-[calc(100%-2rem)] bg-popover text-popover-foreground ring-foreground/10 gap-4 " \
    "rounded-xl p-4 text-sm ring-1 duration-100 sm:max-w-sm #{BACKDROP} data-open:animate-in " \
    "data-open:fade-in-0 data-open:zoom-in-95",
  "cn-sheet-content" =>
    "m-0 w-full gap-4 bg-popover text-popover-foreground text-sm bg-clip-padding shadow-lg " \
    "transition duration-200 ease-in-out data-open:animate-in data-closed:animate-out #{BACKDROP}",
  "cn-sidebar-mobile" =>
    "bg-sidebar p-0 text-sidebar-foreground shadow-lg transition duration-200 ease-in-out " \
    "data-open:animate-in data-closed:animate-out #{BACKDROP}",

  # --- drawer: poetry per-direction rules carry geometry (nova's vaul
  #     chains equal default's edge treatment exactly) --------------------
  "cn-drawer-content" => "bg-popover text-sm text-popover-foreground",
  "cn-drawer-header" => "gap-0.5 p-4 md:gap-0.5 md:text-left",
  "cn-drawer-footer" => :default,

  # --- menus: sub-trigger open-state augmented with poetry's stamped
  #     data-popup-open (upstream's data-open kept verbatim alongside) ----
  "cn-dropdown-menu-sub-trigger" =>
    { base: :upstream, add: %w[data-popup-open:bg-accent data-popup-open:text-accent-foreground] },
  "cn-context-menu-sub-trigger" =>
    { base: :upstream, add: %w[data-popup-open:bg-accent data-popup-open:text-accent-foreground] },
  "cn-menubar-sub-trigger" =>
    { base: :upstream, add: %w[data-popup-open:bg-accent data-popup-open:text-accent-foreground] },
  "cn-context-menu-subcontent" => :upstream_sub_content,
  "cn-menubar-item-indicator" => "left-1.5 size-4 [&_svg:not([class*='size-'])]:size-4",
  # Separator structure (h-px + margins) is poetry's, theme-side; upstream
  # keeps it in markup, so its color-only rule would gut the divider.
  "cn-menubar-separator" => :default,

  "cn-combobox-content" =>
    "bg-popover text-popover-foreground ring-foreground/10 max-h-72 min-w-36 overflow-hidden " \
    "rounded-lg p-0 shadow-md ring-1 duration-100 data-open:animate-in data-open:fade-in-0 " \
    "data-open:zoom-in-95 data-closed:animate-out data-closed:fade-out-0 data-closed:zoom-out-95 " \
    "data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 " \
    "data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2",

  # --- poetry's indicator is an svg dot -> fill idiom ---------------------
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

  # --- toggle group: group-marker chains -> poetry's per-item data attrs;
  #     segmented edge radii consume the W2 side-move (nova rounds lg);
  #     vertical chains dropped (poetry styles the horizontal path) -------
  "cn-toggle-group-item" =>
    "data-[spacing=0]:px-2 data-[spacing=0]:has-data-[icon=inline-end]:pr-1.5 " \
    "data-[spacing=0]:has-data-[icon=inline-start]:pl-1.5 " \
    "data-[spacing=0]:first:rounded-l-lg data-[spacing=0]:last:rounded-r-lg",

  # --- toggle sizes: nova paddings + icon-side twins ----------------------
  "cn-toggle-size-default" =>
    "h-8 min-w-8 px-2.5 has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2 " \
    "has-[>svg:first-child]:pl-2 has-[>svg:last-child]:pr-2",
  "cn-toggle-size-sm" =>
    "h-7 min-w-7 rounded-[min(var(--radius-md),12px)] px-2.5 text-[0.8rem] " \
    "has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 " \
    "has-[>svg:first-child]:pl-1.5 has-[>svg:last-child]:pr-1.5 [&_svg:not([class*='size-'])]:size-3.5",
  "cn-toggle-size-lg" =>
    "h-9 min-w-9 px-2.5 has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2 " \
    "has-[>svg:first-child]:pl-2 has-[>svg:last-child]:pr-2",

  "cn-tooltip-arrow" => "size-2.5 rounded-[2px]", # translate lives inline (spelling twin)

  "cn-attachment-media" =>
    { base: :upstream, sub: { "group-data-[orientation=vertical]/attachment:*:data-[slot=spinner]:size-6!" =>
                              "group-data-[orientation=vertical]/attachment:*:data-[slot=spinner]:size-6" } },

  # --- poetry-own toast family: upstream's rule is a delta over its own
  #     sonner base - poetry keeps the full default body, radius swapped --
  "cn-toast" => { base: :default, sub: { "rounded-md" => "rounded-2xl" } }
}.freeze

HEADER = <<~CSS
  /* poetry nova theme (N12 W2) - upstream style-nova.css ported onto the
   * cn-* layer (pinned clone d0fae528). Same contract as default.css:
   * imported layer(base); bare selectors while installs carry ONE theme;
   * rule order per component = base < elements < variants < compounds;
   * split-side, no-empty-rules and cross-component-last rules apply.
   *
   * Port disciplines identical to vega (see the N12 plan note close-out +
   * docs/nova-port-ledger.txt): verbatim where poetry speaks the
   * vocabulary; data-vertical -> data-[orientation=*]; overlays ->
   * native-dialog backdrop:*; upstream ! stripped except the sidebar
   * collapse geometry; icon paddings ship upstream's has-data-[icon=*]
   * (inert) plus working >svg:first/last-child twins; soft destructive
   * holds AA via relative-oklch light-mode darkening (posture).
   * Nova-judged: the banded alert-dialog footer (the W2 hook); toggle
   * segments round lg via the theme-side edge radii; calendar cell
   * density (--cell-size 7) deferred with the poetry-own engine.
   */
CSS
