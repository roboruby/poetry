# frozen_string_literal: true

# N12 W4 sera plan ("editorial and typographic") for write_theme.rb. The
# editorial theme: uppercase tracked type everywhere (buttons/menus/
# labels/titles at text-xs font-semibold tracking-wider/widest), sizes
# one step UP (h-10 default button, h-11 lg, generous menu px-3 py-2),
# rounded-none universal, UNDERLINE-ONLY form fields (border-transparent
# border-b-input px-0, color/border-color transitions instead of focus
# rings), text-only badges (bg-transparent px-0 text-[0.625rem]),
# left-edge rule alerts (after: w-0.5 bar tinted per variant), flat
# ring-1 cards with --card-spacing 8, filled bg-secondary dialog/sheet
# close buttons, square switch (rounded-none, bordered, +2px thumb
# overshoot), monochrome radios (border-foreground + fill-foreground
# dot), shadow-md overlay temperature, black/20 blur-sm scrims. Fonts:
# the serif pairing is upstream create-flow metadata only - the
# fragment speaks tracking/uppercase/size/weight, ported verbatim; the
# family story belongs to the docs site (W5).
#
# AA posture: no tinted form surfaces (fields are transparent with
# underlines; the lone bg-input/50 is the decorative slider track), so
# the kit reduces to the soft-destructive pair (maia's body) on
# button + the text-only destructive badge, plus mira's 0.8 kbd pair on
# the addon (kbd chips sit on bg-muted-foreground/10 there).
#
# Judged notes: button-group orientation follows upstream (caps-only at
# rounded-none!, neighbor border-collapse dropped) but poetry's
# structural flex-col stays on the vertical rule (the W2 delta-rule
# lesson); tabs-trigger ships poetry's full machinery with sera
# geometry (upstream's active state lives inline in its base component,
# theme-side in poetry); the swipe-axis drawer-handle anatomy is
# upstream vocab poetry never stamps - only the rounded-none delta
# ports; combobox-trigger keeps poetry's body with the icon downsized
# (upstream's own rule is a thin svg-only delta); calendar keeps
# :default ([--cell-radius:0] unconsumed by poetry, cell-size 8 =
# poetry default - zero-cost); sera's embedded dropdown input-group
# rules port verbatim including upstream's own border-transparent-
# after-border-b-input ordering (same computed outcome as upstream).

BACKDROP = "backdrop:bg-black/20 supports-backdrop-filter:backdrop:backdrop-blur-sm"

AA_MUTED8 = "text-[oklch(from_var(--muted-foreground)_calc(l*0.8)_c_h)]"
AA_DESTRUCTIVE85 = "text-[oklch(from_var(--destructive)_calc(l*0.85)_c_h)]"

PLAN = {
  # --- alert: poetry's 0-col grid idiom + sera's left-edge rule bar ------
  "cn-alert" =>
    "grid grid-cols-[0_1fr] items-start gap-1 border bg-background px-4 py-3 text-left text-sm " \
    "has-data-[slot=alert-action]:relative has-data-[slot=alert-action]:pr-18 " \
    "has-[>svg]:grid-cols-[auto_1fr] has-[>svg]:gap-x-2.5 " \
    "[&>svg]:size-4 [&>svg]:translate-y-0.5 [&>svg]:text-current " \
    "relative after:absolute after:-inset-y-px after:-left-px after:w-0.5",
  "cn-alert-title" => "col-start-2 text-sm font-semibold",
  "cn-alert-description" =>
    "col-start-2 text-sm text-muted-foreground text-balance md:text-pretty [&_p:not(:last-child)]:mb-4",

  # --- alert dialog: editorial title, shadow-md, black/20 scrim ----------
  "cn-alert-dialog-content" =>
    "w-full max-w-[calc(100%-2rem)] bg-popover text-popover-foreground ring-foreground/10 " \
    "gap-6 rounded-none p-6 shadow-md ring-1 duration-100 data-[size=default]:max-w-xs " \
    "data-[size=sm]:max-w-xs data-[size=default]:sm:max-w-md #{BACKDROP} " \
    "data-open:animate-in data-open:fade-in-0 data-open:zoom-in-95",
  "cn-alert-dialog-header" => "gap-2",
  "cn-alert-dialog-media" => :default,
  "cn-alert-dialog-title" => "text-lg font-semibold uppercase tracking-wider",

  # --- accordion: NO box; upstream's focus story is complete (ring-2 at
  #     /30), so only the icon trio moves to poetry's own icon rule -------
  "cn-accordion-trigger" =>
    { base: :upstream,
      drop: %w[**:data-[slot=accordion-trigger-icon]:text-muted-foreground
               **:data-[slot=accordion-trigger-icon]:ml-auto
               **:data-[slot=accordion-trigger-icon]:size-3.5] },
  "cn-accordion-trigger-icon" => "ml-auto size-3.5 text-muted-foreground",

  # --- kept-default (poetry anatomy / continuity; see ledger) ------------
  "cn-avatar-badge" => :default,
  "cn-calendar" => :default,

  # --- combobox trigger: poetry body, sera icon size (upstream's own
  #     rule is a thin svg-only delta over its button base) ---------------
  "cn-combobox-trigger" =>
    { base: :default, sub: { "[&_svg:not([class*='size-'])]:size-4" =>
                             "[&_svg:not([class*='size-'])]:size-3.5" } },

  # --- drawer swipe handle: square bar, poetry sizes ----------------------
  "cn-drawer-swipe-handle" =>
    { base: :default, sub: { "after:rounded-full" => "after:rounded-none" } },

  # --- button-group: upstream drops the neighbor collapse and keeps only
  #     squared end caps; poetry's structural flex-col stays vertical -----
  "cn-button-group-orientation-horizontal" =>
    "[&>[data-slot]:not(:has(~[data-slot]))]:rounded-none!",
  "cn-button-group-orientation-vertical" =>
    "flex-col [&>[data-slot]:not(:has(~[data-slot]))]:rounded-none!",

  # --- buttons: sera sizes (one step up) + icon-side twins ----------------
  "cn-button-size-default" =>
    "h-10 gap-1.5 px-6 has-data-[icon=inline-end]:pr-4 has-data-[icon=inline-start]:pl-4 " \
    "has-[>svg:first-child]:pl-4 has-[>svg:last-child]:pr-4",
  "cn-button-size-xs" =>
    "h-7 gap-1 px-3 text-xs has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2 " \
    "has-[>svg:first-child]:pl-2 has-[>svg:last-child]:pr-2 [&_svg:not([class*='size-'])]:size-3",
  "cn-button-size-sm" =>
    "h-9 gap-1 px-4 has-data-[icon=inline-end]:pr-3 has-data-[icon=inline-start]:pl-3 " \
    "has-[>svg:first-child]:pl-3 has-[>svg:last-child]:pr-3",
  "cn-button-size-lg" =>
    "h-11 gap-1.5 px-8 has-data-[icon=inline-end]:pr-5 has-data-[icon=inline-start]:pl-5 " \
    "has-[>svg:first-child]:pl-5 has-[>svg:last-child]:pr-5",

  # --- soft destructive, AA-held (posture; maia's exact body) ------
  "cn-button-variant-destructive" =>
    "bg-destructive/10 hover:bg-destructive/20 focus-visible:ring-destructive/20 " \
    "dark:focus-visible:ring-destructive/40 dark:bg-destructive/20 " \
    "#{AA_DESTRUCTIVE85} dark:text-destructive " \
    "focus-visible:border-destructive/40 dark:hover:bg-destructive/30",
  # text-only destructive badge: the AA hold lands on the base text; the
  # /70 hover fade is upstream's verbatim posture
  "cn-badge-variant-destructive" =>
    "#{AA_DESTRUCTIVE85} dark:text-destructive [a]:hover:text-destructive/70",

  # --- badge: text-only editorial chip (no box at all) --------------------
  "cn-badge" =>
    "gap-1.5 rounded-none border-0 bg-transparent px-0 py-0 text-[0.625rem] font-semibold " \
    "uppercase tracking-widest transition-colors " \
    "has-data-[icon=inline-end]:pr-0 has-data-[icon=inline-start]:pl-0 " \
    "has-[>svg:first-child]:pl-0 has-[>svg:last-child]:pr-0 [&>svg]:size-3",

  "cn-checkbox" => { base: :upstream, drop: %w[group-has-disabled/field:opacity-50] },

  # --- command: poetry keeps structural gap + placeholder color; sera's
  #     underline command box collapses onto the wrapper (border-b is
  #     poetry's own, px-3 = upstream's inner box, py-1 = its outer p-1) --
  "cn-command-input-wrapper" => "gap-2 border-b px-3 py-1",
  "cn-command-input" => "w-full bg-transparent text-sm placeholder:text-muted-foreground",
  "cn-command-group" =>
    { base: :upstream, drop: %w[**:[[cmdk-group-heading]]:text-muted-foreground **:[[cmdk-group-heading]]:px-3
                                **:[[cmdk-group-heading]]:py-2 **:[[cmdk-group-heading]]:text-xs
                                **:[[cmdk-group-heading]]:font-semibold **:[[cmdk-group-heading]]:uppercase
                                **:[[cmdk-group-heading]]:tracking-wider] },
  "cn-command-group-heading" =>
    "px-3 py-2 text-xs font-semibold uppercase tracking-wider text-muted-foreground",

  # --- dialog / sheet / sidebar-mobile: shadow-md, black/20 scrim; the
  #     bare `grid` display token is dropped so the native <dialog> closed
  #     state survives (the W3 rule) ---------------------------------------
  "cn-dialog-content" =>
    "w-full max-w-[calc(100%-2rem)] bg-popover text-popover-foreground ring-foreground/10 " \
    "gap-6 rounded-none p-6 text-sm shadow-md ring-1 duration-100 sm:max-w-md #{BACKDROP} " \
    "data-open:animate-in data-open:fade-in-0 data-open:zoom-in-95",
  "cn-sheet-content" =>
    "m-0 w-full bg-popover text-popover-foreground text-sm bg-clip-padding shadow-md " \
    "transition duration-200 ease-in-out data-open:animate-in data-closed:animate-out #{BACKDROP}",
  "cn-sidebar-mobile" =>
    "bg-sidebar p-0 text-sidebar-foreground shadow-md transition duration-200 ease-in-out " \
    "data-open:animate-in data-closed:animate-out #{BACKDROP}",

  # --- drawer: square panel, borders per side via poetry's own direction
  #     rules ---------------------------------------------------------------
  "cn-drawer-content" => "bg-popover text-popover-foreground text-sm",
  "cn-drawer-direction-down" => "rounded-none border-t",
  "cn-drawer-direction-left" => "rounded-none border-r",
  "cn-drawer-direction-right" => "rounded-none border-l",
  "cn-drawer-direction-up" => "rounded-none border-b",

  # --- menus ---------------------------------------------------------------
  "cn-dropdown-menu-sub-trigger" =>
    { base: :upstream, add: %w[data-popup-open:bg-accent data-popup-open:text-accent-foreground] },
  "cn-context-menu-sub-trigger" =>
    { base: :upstream, add: %w[data-popup-open:bg-accent data-popup-open:text-accent-foreground] },
  "cn-menubar-sub-trigger" =>
    { base: :upstream, add: %w[data-popup-open:bg-accent data-popup-open:text-accent-foreground] },
  "cn-context-menu-subcontent" => :upstream_sub_content,
  "cn-menubar-item-indicator" => "left-3 size-4 [&_svg:not([class*='size-'])]:size-4",

  "cn-combobox-content" =>
    "bg-popover text-popover-foreground ring-foreground/10 " \
    "*:data-[slot=input-group]:bg-transparent *:data-[slot=input-group]:border-b-input " \
    "*:data-[slot=input-group]:m-1.5 *:data-[slot=input-group]:mb-0 *:data-[slot=input-group]:h-8 " \
    "*:data-[slot=input-group]:border-transparent *:data-[slot=input-group]:focus-within:border-transparent " \
    "*:data-[slot=input-group]:px-2.5 max-h-72 min-w-36 overflow-hidden rounded-none p-0 " \
    "shadow-md ring-1 duration-100 data-open:animate-in data-open:fade-in-0 data-open:zoom-in-95 " \
    "data-closed:animate-out data-closed:fade-out-0 data-closed:zoom-out-95 " \
    "data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 " \
    "data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2",

  # --- poetry's indicator is an svg dot -> fill idiom (sera is
  #     monochrome: border-foreground item, foreground dot) ----------------
  "cn-radio-group-indicator-icon" => "size-2 fill-foreground",

  # --- vocabulary translations -------------------------------------------
  "cn-slider" => { base: :upstream, sub: { "data-vertical:min-h-40" => "data-[orientation=vertical]:min-h-40" } },
  "cn-slider-track" =>
    { base: :upstream, sub: {
      "data-horizontal:h-0.5" => "data-[orientation=horizontal]:h-0.5",
      "data-horizontal:w-full" => "data-[orientation=horizontal]:w-full",
      "data-vertical:h-full" => "data-[orientation=vertical]:h-full",
      "data-vertical:w-0.5" => "data-[orientation=vertical]:w-0.5"
    } },
  # square thumb overshoots the track edge by 2px; poetry's rtl twins come
  # along at the same +2px travel (and the 1px unchecked inset mirrors)
  "cn-switch-thumb" =>
    { base: :upstream, add: %w[rtl:data-checked:-translate-x-[calc(100%+2px)]
                               rtl:data-unchecked:-translate-x-0.25] },
  "cn-table-row" =>
    "border-b transition-colors hover:bg-muted/50 has-aria-expanded:bg-muted/50 data-selected:bg-muted",

  # --- tabs: poetry's full active/line machinery, sera geometry (the
  #     whole-cluster discipline; upstream's active state lives inline in
  #     its base component, theme-side in poetry) --------------------------
  "cn-tabs-trigger" =>
    "gap-2 rounded-none border border-transparent px-4 py-1.5 text-xs font-semibold uppercase " \
    "tracking-wider text-foreground/60 hover:text-foreground " \
    "has-data-[icon=inline-end]:pr-2.5 has-data-[icon=inline-start]:pl-2.5 " \
    "dark:text-muted-foreground dark:hover:text-foreground " \
    "group-data-[variant=default]/tabs-list:data-active:shadow-sm " \
    "group-data-[variant=line]/tabs-list:data-active:shadow-none [&_svg:not([class*='size-'])]:size-3.5 " \
    "group-data-[variant=line]/tabs-list:bg-transparent " \
    "group-data-[variant=line]/tabs-list:data-active:bg-transparent " \
    "dark:group-data-[variant=line]/tabs-list:data-active:border-transparent " \
    "dark:group-data-[variant=line]/tabs-list:data-active:bg-transparent " \
    "data-active:bg-background data-active:text-foreground dark:data-active:border-input " \
    "dark:data-active:bg-input/30 dark:data-active:text-foreground after:bg-foreground " \
    "group-data-horizontal/tabs:after:inset-x-0 group-data-horizontal/tabs:after:bottom-[-5px] " \
    "group-data-horizontal/tabs:after:h-0.5 group-data-vertical/tabs:after:inset-y-0 " \
    "group-data-vertical/tabs:after:-right-1 group-data-vertical/tabs:after:w-0.5 " \
    "group-data-[variant=line]/tabs-list:data-active:after:opacity-100 " \
    "group-data-vertical/tabs:px-4 group-data-vertical/tabs:py-2",

  # --- toggle group: item-scoped translation of upstream's group-scoped
  #     spacing cluster + the data-[state=on] -> pressed pair --------------
  "cn-toggle-group-item" =>
    "data-pressed:bg-muted data-pressed:text-foreground " \
    "data-[spacing=0]:rounded-none data-[spacing=0]:px-6 data-[spacing=0]:shadow-none " \
    "data-[spacing=0]:has-data-[icon=inline-end]:pr-4 data-[spacing=0]:has-data-[icon=inline-start]:pl-4 " \
    "data-[spacing=0]:first:rounded-none data-[spacing=0]:last:rounded-none",

  "cn-toggle-size-default" =>
    "h-10 min-w-10 px-6 has-data-[icon=inline-end]:pr-4 has-data-[icon=inline-start]:pl-4 " \
    "has-[>svg:first-child]:pl-4 has-[>svg:last-child]:pr-4",
  "cn-toggle-size-sm" =>
    "h-9 min-w-9 px-4 has-data-[icon=inline-end]:pr-3 has-data-[icon=inline-start]:pl-3 " \
    "has-[>svg:first-child]:pl-3 has-[>svg:last-child]:pr-3",
  "cn-toggle-size-lg" =>
    "h-11 min-w-11 px-8 has-data-[icon=inline-end]:pr-5 has-data-[icon=inline-start]:pl-5 " \
    "has-[>svg:first-child]:pl-5 has-[>svg:last-child]:pr-5",

  "cn-attachment-media" =>
    { base: :upstream, sub: { "group-data-[orientation=vertical]/attachment:*:data-[slot=spinner]:size-6!" =>
                              "group-data-[orientation=vertical]/attachment:*:data-[slot=spinner]:size-6" } },

  # --- poetry-own toast family: upstream's rule is a bang-radius delta
  #     over its own sonner base - poetry keeps the full default body,
  #     radius squared plain (bang policy) ---------------------------------
  "cn-toast" => { base: :default, sub: { "rounded-md" => "rounded-none" } },

  # --- form controls: underline fields; the placeholder token returns
  #     with the W2 side-move (upstream omits it) --------------------------
  "cn-input" => { base: :upstream, add: %w[placeholder:text-muted-foreground] },
  "cn-textarea" => { base: :upstream, add: %w[placeholder:text-muted-foreground] },

  # --- input-group addon: mira's doubled-tint kbd pair up front (kbd
  #     chips sit on bg-muted-foreground/10; a child's own color rule
  #     beats inherited darkening, the **: twin outranks it) ---------------
  "cn-input-group-addon" =>
    "text-muted-foreground **:data-[slot=kbd]:bg-muted-foreground/10 " \
    "**:data-[slot=kbd]:#{AA_MUTED8} " \
    "dark:**:data-[slot=kbd]:text-muted-foreground " \
    "h-auto gap-2 py-2 text-sm font-medium group-data-[disabled=true]/input-group:opacity-50 " \
    "**:data-[slot=kbd]:rounded-none **:data-[slot=kbd]:px-1.5 [&>svg:not([class*='size-'])]:size-3.5"
}.freeze

HEADER = <<~CSS
  /* poetry sera theme (N12 W4) - upstream style-sera.css ported onto the
   * cn-* layer (pinned clone d0fae528). Same contract as default.css:
   * imported layer(base); bare selectors while installs carry ONE theme;
   * rule order per component = base < elements < variants < compounds;
   * split-side, no-empty-rules and cross-component-last rules apply.
   *
   * Port disciplines identical to vega/rhea (see the N12 plan note
   * close-outs + docs/sera-port-ledger.txt): verbatim where poetry
   * speaks the vocabulary; data-vertical -> data-[orientation=*];
   * data-[state=on] -> data-pressed; overlays -> native-dialog
   * backdrop:* (black/20 blur-sm); upstream ! stripped except the
   * sidebar collapse geometry and default-inherited precedents; icon
   * paddings ship upstream's has-data-[icon=*] (inert) plus working
   * >svg:first/last-child twins; soft destructive holds AA via
   * relative-oklch light-mode darkening (posture). Sera-specific:
   * editorial uppercase tracked type at every level with sizes one step
   * up (h-10 buttons), rounded-none universal, underline-only form
   * fields (border-b transitions instead of focus rings), text-only
   * badges, left-edge rule alerts, flat ring-1 cards on --card-spacing
   * 8, filled bg-secondary close buttons, square bordered switch with
   * +2px thumb overshoot (poetry rtl twins ride along), monochrome
   * radios (fill-foreground dot), button-group caps-only geometry over
   * poetry's structural flex-col, and mira's 0.8 kbd pair on the addon
   * (the only AA hold beyond destructive - fields are untinted). Fonts
   * move via tracking/uppercase/size/weight utilities only - the serif
   * pairing is upstream create-flow metadata, told in docs, not CSS.
   */
CSS
