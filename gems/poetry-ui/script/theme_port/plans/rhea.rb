# frozen_string_literal: true

# N12 W2 rhea plan ("like Luma but compact") for write_theme.rb. The
# soft-round compact: radius-4xl dialogs (min-capped 24px), rounded-2xl
# accordion box + badge pill, rounded-3xl command, split ring temperature
# (ring-foreground/5 light, /10 dark), shadow-xl overlays, bg-input/90
# form surfaces. Judged notes: accordion trigger gains poetry's
# focus-visible cluster (upstream ships none); the floating
# before:-frame drawer is deferred (edge-attached idiom kept, ledgered);
# data-[state=on] -> data-pressed on toggle-group items.

# NOTE: the shipped themes/rhea.css has been hand-edited since generation
# (bang audit, thin-body fixes, axe AA holds, W2 side-move consumers) - the
# fragment is canon; write_theme.rb refuses to regenerate over it.

BACKDROP = "backdrop:bg-black/10 supports-backdrop-filter:backdrop:backdrop-blur-xs"

PLAN = {
  # --- alert: poetry's 0-col grid idiom carries; rhea skin lands on it ---
  "cn-alert" =>
    "grid grid-cols-[0_1fr] items-start gap-0.5 rounded-2xl border px-4 py-3 text-left text-sm " \
    "has-data-[slot=alert-action]:relative has-data-[slot=alert-action]:pr-18 " \
    "has-[>svg]:grid-cols-[auto_1fr] has-[>svg]:gap-x-2.5 " \
    "[&>svg]:size-4 [&>svg]:translate-y-0.5 [&>svg]:text-current",
  "cn-alert-title" => "col-start-2 font-medium",
  "cn-alert-description" =>
    "col-start-2 text-sm text-muted-foreground text-balance md:text-pretty [&_p:not(:last-child)]:mb-4",

  # --- alert dialog -------------------------------------------------------
  "cn-alert-dialog-content" =>
    "w-full max-w-[calc(100%-2rem)] bg-popover text-popover-foreground ring-foreground/5 " \
    "dark:ring-foreground/10 gap-6 rounded-[min(var(--radius-4xl),24px)] p-6 shadow-xl ring-1 " \
    "duration-100 data-[size=default]:max-w-xs data-[size=sm]:max-w-xs " \
    "data-[size=default]:sm:max-w-md #{BACKDROP} data-open:animate-in data-open:fade-in-0 " \
    "data-open:zoom-in-95",
  "cn-alert-dialog-header" => "gap-1.5",
  "cn-alert-dialog-media" => :default,
  "cn-alert-dialog-title" => "text-lg font-medium",
  # (cn-alert-dialog-footer: rhea does not band it - inherits default's gap-2)

  # --- accordion: the boxed root (the W2 hook mira/rhea exist for);
  #     poetry focus cluster added (upstream ships no focus-visible) ------
  "cn-accordion" => "w-full overflow-hidden rounded-2xl border",
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
  "cn-calendar" => :default,
  "cn-combobox-trigger" => :default,
  "cn-drawer-swipe-handle" => :default,
  "cn-switch-thumb" => :default,
  "cn-tabs-trigger" => :default,

  # --- buttons: rhea sizes + the >svg:first/last-child icon-side twins ---
  "cn-button-size-default" =>
    "h-8 gap-1.5 px-3 has-data-[icon=inline-end]:pr-2.5 has-data-[icon=inline-start]:pl-2.5 " \
    "has-[>svg:first-child]:pl-2.5 has-[>svg:last-child]:pr-2.5",
  "cn-button-size-xs" =>
    "h-6 gap-1 px-2.5 text-xs has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2 " \
    "has-[>svg:first-child]:pl-2 has-[>svg:last-child]:pr-2 [&_svg:not([class*='size-'])]:size-3",
  "cn-button-size-sm" =>
    "h-7 gap-1 px-3 has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2 " \
    "has-[>svg:first-child]:pl-2 has-[>svg:last-child]:pr-2",
  "cn-button-size-lg" =>
    "h-9 gap-1.5 px-4 has-data-[icon=inline-end]:pr-3 has-data-[icon=inline-start]:pl-3 " \
    "has-[>svg:first-child]:pl-3 has-[>svg:last-child]:pr-3",

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

  # --- badge: rhea 2xl pill; svg-size bang stripped (policy) -------------
  "cn-badge" =>
    "h-5 gap-1 rounded-2xl border border-transparent px-2 py-0.5 text-xs font-medium transition-all " \
    "has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 " \
    "has-[>svg:first-child]:pl-1.5 has-[>svg:last-child]:pr-1.5 [&>svg]:size-3",

  "cn-checkbox" => { base: :upstream, drop: %w[group-has-disabled/field:opacity-50] },

  # --- command: rhea's flat search row; poetry keeps structural gap +
  #     placeholder color (anatomy needs) ---------------------------------
  "cn-command-input-wrapper" => "gap-2 p-1 pb-0",
  "cn-command-input" => "w-full bg-transparent text-sm placeholder:text-muted-foreground",
  "cn-command-group" =>
    { base: :upstream, drop: %w[**:[[cmdk-group-heading]]:text-muted-foreground **:[[cmdk-group-heading]]:px-2
                                **:[[cmdk-group-heading]]:py-1.5 **:[[cmdk-group-heading]]:text-xs
                                **:[[cmdk-group-heading]]:font-medium] },

  # --- dialog / sheet / sidebar-mobile ------------------------------------
  "cn-dialog-content" =>
    "w-full max-w-[calc(100%-2rem)] bg-popover text-popover-foreground ring-foreground/5 " \
    "dark:ring-foreground/10 gap-6 rounded-[min(var(--radius-4xl),24px)] p-6 text-sm shadow-xl " \
    "ring-1 duration-100 sm:max-w-md #{BACKDROP} data-open:animate-in data-open:fade-in-0 " \
    "data-open:zoom-in-95",
  "cn-sheet-content" =>
    "m-0 w-full bg-popover text-popover-foreground text-sm bg-clip-padding shadow-xl " \
    "transition duration-200 ease-in-out data-open:animate-in data-closed:animate-out #{BACKDROP}",
  "cn-sidebar-mobile" =>
    "bg-sidebar p-0 text-sidebar-foreground shadow-xl transition duration-200 ease-in-out " \
    "data-open:animate-in data-closed:animate-out #{BACKDROP}",

  # --- drawer: edge-attached idiom kept; the before:-frame is deferred ---
  "cn-drawer-content" => "bg-popover text-sm text-popover-foreground",
  "cn-drawer-header" => "gap-0.5 p-4 md:gap-1.5 md:text-left",
  "cn-drawer-footer" => :default,

  # --- menus ---------------------------------------------------------------
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
  "cn-menubar-separator" => "-mx-1 my-1 h-px bg-border/50",

  "cn-combobox-content" =>
    "bg-popover text-popover-foreground ring-foreground/5 dark:ring-foreground/10 max-h-72 min-w-36 " \
    "overflow-hidden rounded-2xl p-0 shadow-lg ring-1 duration-100 data-open:animate-in " \
    "data-open:fade-in-0 data-open:zoom-in-95 data-closed:animate-out data-closed:fade-out-0 " \
    "data-closed:zoom-out-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 " \
    "data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2",

  # --- poetry's indicator is an svg dot -> fill idiom ---------------------
  "cn-radio-group-indicator-icon" => "size-2 dark:size-2.5 fill-primary-foreground",

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

  # --- toggle group: per-item translation (data-[state=on] -> pressed);
  #     rhea segments round 2xl via the W2 side-move -----------------------
  "cn-toggle-group-item" =>
    "data-pressed:bg-muted data-[spacing=0]:px-2 data-[spacing=0]:shadow-none " \
    "data-[spacing=0]:has-data-[icon=inline-end]:pr-1.5 data-[spacing=0]:has-data-[icon=inline-start]:pl-1.5 " \
    "data-[spacing=0]:rounded-none " \
    "data-[spacing=0]:first:rounded-l-2xl data-[spacing=0]:last:rounded-r-2xl",

  "cn-toggle-size-default" =>
    "h-8 min-w-8 px-2.5 has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2 " \
    "has-[>svg:first-child]:pl-2 has-[>svg:last-child]:pr-2",
  "cn-toggle-size-sm" =>
    "h-7 min-w-7 px-2.5 has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 " \
    "has-[>svg:first-child]:pl-1.5 has-[>svg:last-child]:pr-1.5",
  "cn-toggle-size-lg" =>
    "h-9 min-w-9 px-2.5 has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2 " \
    "has-[>svg:first-child]:pl-2 has-[>svg:last-child]:pr-2",

  # rhea nudges the arrow horizontally per side (new x-vars compose with
  # the inline translate-y spelling twin via the shared --tw vars).
  "cn-tooltip-arrow" =>
    "size-2.5 rounded-[2px] data-[side=left]:translate-x-[-1.5px] data-[side=right]:translate-x-[1.5px]",

  "cn-attachment-media" =>
    { base: :upstream, sub: { "group-data-[orientation=vertical]/attachment:*:data-[slot=spinner]:size-6!" =>
                              "group-data-[orientation=vertical]/attachment:*:data-[slot=spinner]:size-6" } },

  # --- poetry-own toast family: upstream's rule is a delta over its own
  #     sonner base - poetry keeps the full default body, radius swapped
  #     (upstream's ! dropped with the delta) ------------------------------
  "cn-toast" => { base: :default, sub: { "rounded-md" => "rounded-2xl" } }
}.freeze

HEADER = <<~CSS
  /* poetry rhea theme (N12 W2) - upstream style-rhea.css ported onto the
   * cn-* layer (pinned clone d0fae528). Same contract as default.css:
   * imported layer(base); bare selectors while installs carry ONE theme;
   * rule order per component = base < elements < variants < compounds;
   * split-side, no-empty-rules and cross-component-last rules apply.
   *
   * Port disciplines identical to vega (see the N12 plan note close-out +
   * docs/rhea-port-ledger.txt): verbatim where poetry speaks the
   * vocabulary; data-vertical -> data-[orientation=*]; data-[state=on] ->
   * data-pressed; overlays -> native-dialog backdrop:*; upstream !
   * stripped except the sidebar collapse geometry; icon paddings ship
   * upstream's has-data-[icon=*] (inert) plus working
   * >svg:first/last-child twins; soft destructive holds AA via
   * relative-oklch light-mode darkening (posture). Rhea-judged:
   * boxed 2xl accordion root (the W2 hook); accordion trigger carries
   * poetry's focus-visible cluster (upstream ships none); the floating
   * before:-frame drawer is deferred (edge-attached idiom kept).
   */
CSS
