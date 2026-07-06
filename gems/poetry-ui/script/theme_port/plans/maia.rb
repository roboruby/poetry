# frozen_string_literal: true

# N12 W3 maia plan ("rounded, generous spacing") for write_theme.rb. The
# soft-round standard: rounded-4xl dialogs/pills/tabs-lists on ring-only
# surfaces (ring-foreground/5, cards ring-foreground/10, NO dialog
# shadow), boxed rounded-2xl accordion (the W2 carrier), rounded-xl tab
# triggers inside rounded-4xl lists, bg-input/30 LIGHT-MODE form tints,
# black/80 blur-xs scrims, soft destructive (AA-held). Anatomy set is
# byte-identical to rhea's triage - this plan mirrors plans/rhea.rb with
# maia values; deviations from W2: tabs-trigger ships poetry's full
# machinery with maia geometry swapped in (the whole-cluster discipline;
# W2's :default was only safe because nova/mira kept default radius),
# and button-group end-caps port via :default+sub (rhea inherited).
# Judged notes: accordion trigger gains poetry's focus-visible cluster
# (upstream ships none); calendar keeps :default (poetry consumes
# --cell-size inline only, never --cell-radius; maia's cell-size 8 =
# poetry default anyway - zero-cost defer); alert-dialog-media stays
# poetry anatomy (rhea precedent; not judgeable in composed captures).
# AA posture: /30 tints are lighter than rhea's /50 - placeholders ship
# standard and axe arbitrates; the addon kbd doubled tint
# (muted-foreground/10 over input/30) gets mira's 0.8 pair up front.

BACKDROP = "backdrop:bg-black/80 supports-backdrop-filter:backdrop:backdrop-blur-xs"

PLAN = {
  # --- alert: poetry's 0-col grid idiom carries; maia skin lands on it ---
  "cn-alert" =>
    "grid grid-cols-[0_1fr] items-start gap-0.5 rounded-lg border px-4 py-3 text-left text-sm " \
    "has-data-[slot=alert-action]:relative has-data-[slot=alert-action]:pr-18 " \
    "has-[>svg]:grid-cols-[auto_1fr] has-[>svg]:gap-x-2.5 " \
    "[&>svg]:size-4 [&>svg]:translate-y-0.5 [&>svg]:text-current",
  "cn-alert-title" => "col-start-2 font-medium",
  "cn-alert-description" =>
    "col-start-2 text-sm text-muted-foreground text-balance md:text-pretty [&_p:not(:last-child)]:mb-4",

  # --- alert dialog: flat ring-only (no shadow, no dark ring split) ------
  "cn-alert-dialog-content" =>
    "w-full max-w-[calc(100%-2rem)] bg-popover text-popover-foreground ring-foreground/5 " \
    "gap-6 rounded-4xl p-6 ring-1 duration-100 data-[size=default]:max-w-xs data-[size=sm]:max-w-xs " \
    "data-[size=default]:sm:max-w-md #{BACKDROP} data-open:animate-in data-open:fade-in-0 " \
    "data-open:zoom-in-95",
  "cn-alert-dialog-header" => "gap-1.5",
  "cn-alert-dialog-media" => :default,
  "cn-alert-dialog-title" => "text-lg font-medium",
  # (cn-alert-dialog-footer: maia does not band it - inherits default's gap-2)

  # --- accordion: the boxed root (the W2 carrier); poetry focus cluster
  #     added (upstream ships no focus-visible) ---------------------------
  "cn-accordion" => "w-full overflow-hidden rounded-2xl border",
  "cn-accordion-trigger" =>
    { base: :upstream,
      drop: %w[**:data-[slot=accordion-trigger-icon]:text-muted-foreground
               **:data-[slot=accordion-trigger-icon]:ml-auto
               **:data-[slot=accordion-trigger-icon]:size-4],
      add: %w[focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50] },
  "cn-accordion-trigger-icon" => "ml-auto size-4 text-muted-foreground",

  # --- kept-default (poetry anatomy / continuity; see ledger) ------------
  "cn-avatar-badge" => :default,
  "cn-calendar" => :default,
  "cn-combobox-trigger" => :default,
  "cn-drawer-swipe-handle" => :default,
  "cn-switch-thumb" => :default,

  # --- button-group end caps: default bodies, maia 4xl caps (the bangs
  #     are the default-inherited precedent) ------------------------------
  "cn-button-group-orientation-horizontal" =>
    { base: :default, sub: { "rounded-r-md!" => "rounded-r-4xl!" } },
  "cn-button-group-orientation-vertical" =>
    { base: :default, sub: { "rounded-b-md!" => "rounded-b-4xl!" } },

  # --- buttons: maia sizes + the >svg:first/last-child icon-side twins ---
  "cn-button-size-default" =>
    "h-9 gap-1.5 px-3 has-data-[icon=inline-end]:pr-2.5 has-data-[icon=inline-start]:pl-2.5 " \
    "has-[>svg:first-child]:pl-2.5 has-[>svg:last-child]:pr-2.5",
  "cn-button-size-xs" =>
    "h-6 gap-1 px-2.5 text-xs has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2 " \
    "has-[>svg:first-child]:pl-2 has-[>svg:last-child]:pr-2 [&_svg:not([class*='size-'])]:size-3",
  "cn-button-size-sm" =>
    "h-8 gap-1 px-3 has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2 " \
    "has-[>svg:first-child]:pl-2 has-[>svg:last-child]:pr-2",
  "cn-button-size-lg" =>
    "h-10 gap-1.5 px-4 has-data-[icon=inline-end]:pr-3 has-data-[icon=inline-start]:pl-3 " \
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

  # --- badge: maia 4xl pill; svg-size bang stripped (policy) -------------
  "cn-badge" =>
    "h-5 gap-1 rounded-4xl border border-transparent px-2 py-0.5 text-xs font-medium transition-all " \
    "has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 " \
    "has-[>svg:first-child]:pl-1.5 has-[>svg:last-child]:pr-1.5 [&>svg]:size-3",

  "cn-checkbox" => { base: :upstream, drop: %w[group-has-disabled/field:opacity-50] },

  # --- command: poetry keeps structural gap + placeholder color ----------
  "cn-command-input-wrapper" => "gap-2 p-1 pb-0",
  "cn-command-input" => "w-full bg-transparent text-sm placeholder:text-muted-foreground",
  "cn-command-group" =>
    { base: :upstream, drop: %w[**:[[cmdk-group-heading]]:text-muted-foreground **:[[cmdk-group-heading]]:px-3
                                **:[[cmdk-group-heading]]:py-2 **:[[cmdk-group-heading]]:text-xs
                                **:[[cmdk-group-heading]]:font-medium] },

  # --- dialog / sheet / sidebar-mobile ------------------------------------
  "cn-dialog-content" =>
    "w-full max-w-[calc(100%-2rem)] bg-popover text-popover-foreground ring-foreground/5 " \
    "gap-6 rounded-4xl p-6 text-sm ring-1 duration-100 sm:max-w-md #{BACKDROP} " \
    "data-open:animate-in data-open:fade-in-0 data-open:zoom-in-95",
  "cn-sheet-content" =>
    "m-0 w-full bg-popover text-popover-foreground text-sm bg-clip-padding shadow-lg " \
    "transition duration-200 ease-in-out data-open:animate-in data-closed:animate-out #{BACKDROP}",
  "cn-sidebar-mobile" =>
    "bg-sidebar p-0 text-sidebar-foreground shadow-lg transition duration-200 ease-in-out " \
    "data-open:animate-in data-closed:animate-out #{BACKDROP}",

  # --- drawer: maia does not speak to the popup; poetry idiom kept -------
  "cn-drawer-content" => :default,
  "cn-drawer-header" => "gap-0.5 p-4 md:gap-1.5 md:text-left",
  "cn-drawer-footer" => "gap-2 p-4",

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
    "bg-popover text-popover-foreground ring-foreground/5 max-h-72 min-w-36 " \
    "overflow-hidden rounded-2xl p-0 shadow-2xl ring-1 duration-100 data-open:animate-in " \
    "data-open:fade-in-0 data-open:zoom-in-95 data-closed:animate-out data-closed:fade-out-0 " \
    "data-closed:zoom-out-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 " \
    "data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2",

  # --- poetry's indicator is an svg dot -> fill idiom ---------------------
  "cn-radio-group-indicator-icon" => "size-2 fill-primary-foreground",

  # --- vocabulary translations -------------------------------------------
  "cn-slider" => { base: :upstream, sub: { "data-vertical:min-h-40" => "data-[orientation=vertical]:min-h-40" } },
  "cn-slider-track" =>
    { base: :upstream, sub: {
      "data-horizontal:h-3" => "data-[orientation=horizontal]:h-3",
      "data-horizontal:w-full" => "data-[orientation=horizontal]:w-full",
      "data-vertical:h-full" => "data-[orientation=vertical]:h-full",
      "data-vertical:w-3" => "data-[orientation=vertical]:w-3"
    } },
  "cn-table-row" =>
    "border-b transition-colors hover:bg-muted/50 has-aria-expanded:bg-muted/50 data-selected:bg-muted",

  # --- tabs: poetry's full active/line machinery, maia geometry (the
  #     whole-cluster discipline; nova/mira kept default radius so W2's
  #     :default was a coincidence, not the rule) --------------------------
  "cn-tabs-trigger" =>
    "gap-1.5 rounded-xl border border-transparent px-2 py-1 text-sm font-medium text-foreground/60 " \
    "hover:text-foreground has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 " \
    "dark:text-muted-foreground dark:hover:text-foreground " \
    "group-data-[variant=default]/tabs-list:data-active:shadow-sm " \
    "group-data-[variant=line]/tabs-list:data-active:shadow-none [&_svg:not([class*='size-'])]:size-4 " \
    "group-data-[variant=line]/tabs-list:bg-transparent " \
    "group-data-[variant=line]/tabs-list:data-active:bg-transparent " \
    "dark:group-data-[variant=line]/tabs-list:data-active:border-transparent " \
    "dark:group-data-[variant=line]/tabs-list:data-active:bg-transparent " \
    "data-active:bg-background data-active:text-foreground dark:data-active:border-input " \
    "dark:data-active:bg-input/30 after:bg-foreground group-data-horizontal/tabs:after:inset-x-0 " \
    "group-data-horizontal/tabs:after:bottom-[-5px] group-data-horizontal/tabs:after:h-0.5 " \
    "group-data-vertical/tabs:after:inset-y-0 group-data-vertical/tabs:after:-right-1 " \
    "group-data-vertical/tabs:after:w-0.5 " \
    "group-data-[variant=line]/tabs-list:data-active:after:opacity-100 " \
    "group-data-vertical/tabs:px-2.5 group-data-vertical/tabs:py-1.5",

  # --- toggle group: per-item translation (data-[state=on] -> pressed);
  #     whole radius cluster theme-side (the W2 lesson) --------------------
  "cn-toggle-group-item" =>
    "data-pressed:bg-muted data-[spacing=0]:px-3 data-[spacing=0]:shadow-none " \
    "data-[spacing=0]:has-data-[icon=inline-end]:pr-2.5 data-[spacing=0]:has-data-[icon=inline-start]:pl-2.5 " \
    "data-[spacing=0]:rounded-none " \
    "data-[spacing=0]:first:rounded-l-3xl data-[spacing=0]:last:rounded-r-3xl",

  "cn-toggle-size-default" =>
    "h-9 min-w-9 px-3 has-data-[icon=inline-end]:pr-2.5 has-data-[icon=inline-start]:pl-2.5 " \
    "has-[>svg:first-child]:pl-2.5 has-[>svg:last-child]:pr-2.5",
  "cn-toggle-size-sm" =>
    "h-8 min-w-8 px-3 has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2 " \
    "has-[>svg:first-child]:pl-2 has-[>svg:last-child]:pr-2",
  "cn-toggle-size-lg" =>
    "h-10 min-w-10 px-4 has-data-[icon=inline-end]:pr-3 has-data-[icon=inline-start]:pl-3 " \
    "has-[>svg:first-child]:pl-3 has-[>svg:last-child]:pr-3",

  # maia nudges the arrow horizontally per side (new x-vars compose with
  # the inline translate-y spelling twin via the shared --tw vars).
  "cn-tooltip-arrow" =>
    "size-2.5 rounded-[2px] data-[side=left]:translate-x-[-1.5px] data-[side=right]:translate-x-[1.5px]",

  "cn-attachment-media" =>
    { base: :upstream, sub: { "group-data-[orientation=vertical]/attachment:*:data-[slot=spinner]:size-6!" =>
                              "group-data-[orientation=vertical]/attachment:*:data-[slot=spinner]:size-6" } },

  # --- poetry-own toast family: upstream's rule is a delta over its own
  #     sonner base - poetry keeps the full default body, radius swapped --
  "cn-toast" => { base: :default, sub: { "rounded-md" => "rounded-2xl" } },

  # --- form controls: /30 light tints; placeholder token returns with the
  #     W2 side-move (default carries it theme-side, upstream omits it) ---
  "cn-input" => { base: :upstream, add: %w[placeholder:text-muted-foreground] },
  "cn-textarea" => { base: :upstream, add: %w[placeholder:text-muted-foreground] },

  # --- input-group addon: mira's doubled-tint kbd pair up front (kbd tint
  #     over /30 group tint; a child's own color rule beats inherited
  #     darkening, the **: twin outranks it) -------------------------------
  "cn-input-group-addon" =>
    "text-muted-foreground **:data-[slot=kbd]:bg-muted-foreground/10 " \
    "**:data-[slot=kbd]:text-[oklch(from_var(--muted-foreground)_calc(l*0.8)_c_h)] " \
    "dark:**:data-[slot=kbd]:text-muted-foreground " \
    "h-auto gap-2 py-2 text-sm font-medium group-data-[disabled=true]/input-group:opacity-50 " \
    "**:data-[slot=kbd]:rounded-4xl **:data-[slot=kbd]:px-1.5 [&>svg:not([class*='size-'])]:size-4"
}.freeze

HEADER = <<~CSS
  /* poetry maia theme (N12 W3) - upstream style-maia.css ported onto the
   * cn-* layer (pinned clone d0fae528). Same contract as default.css:
   * imported layer(base); bare selectors while installs carry ONE theme;
   * rule order per component = base < elements < variants < compounds;
   * split-side, no-empty-rules and cross-component-last rules apply.
   *
   * Port disciplines identical to vega/rhea (see the N12 plan note
   * close-outs + docs/maia-port-ledger.txt): verbatim where poetry
   * speaks the vocabulary; data-vertical -> data-[orientation=*];
   * data-[state=on] -> data-pressed; overlays -> native-dialog
   * backdrop:* (black/80 blur-xs); upstream ! stripped except the
   * sidebar collapse geometry and default-inherited precedents; icon
   * paddings ship upstream's has-data-[icon=*] (inert) plus working
   * >svg:first/last-child twins; soft destructive holds AA via
   * relative-oklch light-mode darkening (posture). Maia-specific:
   * flat ring-only dialogs (no shadow), rounded-2xl boxed accordion (the
   * W2 carrier), tabs-trigger ships poetry's full machinery with maia
   * geometry (whole-cluster discipline), bg-input/30 light-mode form
   * tints with mira's 0.8 kbd pair on the doubled addon tint.
   */
CSS
