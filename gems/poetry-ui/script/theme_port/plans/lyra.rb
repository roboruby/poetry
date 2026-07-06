# frozen_string_literal: true

# N12 W4 lyra plan ("boxy and sharp, for mono fonts") for write_theme.rb.
# The dense console theme: rounded-none EVERYWHERE, whole type scale one
# step down (text-xs bodies, text-sm titles), ring-1 focus temperature,
# muted-based hovers (hover:bg-muted, never accent), right-side menu
# indicators (absolute right-2, inset pl-7), filled radios
# (data-checked:bg-primary + primary-foreground dot), press-nudge
# buttons (active:translate-y-px, bg-clip-padding), --card-spacing var
# cards on ring-foreground/10, flat sheets/sidebar-mobile (no shadow),
# black/10 blur-xs scrims (the faintest of the series). Fonts: upstream
# pairs lyra with mono FAMILIES via create-flow metadata only - the
# fragment moves typography through size/weight/tracking utilities, so
# the port carries them verbatim and the mono pairing story belongs to
# the docs site (W5), not the CSS.
#
# AA posture: lyra's tints are disabled-state fills (bg-input/50 light,
# /80 dark - WCAG-exempt) and /30 embedded dropdown search boxes (the
# maia class - placeholders ship standard, axe arbitrates); the addon
# kbd keeps default bg-muted colors, so NO relative-oklch kit is needed
# beyond the soft-destructive pair (posture, maia's exact body).
#
# Parse note (upstream quirk, ledgered): style-lyra.css line 1358
# (cn-menu-translucent, a dropped upstream-only box) ends its @apply
# WITHOUT a semicolon, so detector.rb swallowed cn-bubble into it -
# cn-bubble ships here as an explicit judged value transcribed from the
# raw fragment (line 1363). Sera's fragment is clean.
#
# Judged notes: calendar keeps :default and the [--cell-size:--spacing(7)]
# split-side hit joins the nova-7/mira-6 deferral (poetry consumes
# --cell-size inline only); cn-input-group-button-size-sm fired its W1
# return-condition but the condition is about POETRY shipping the size
# (mira ledger) - poetry's input-group anatomy is unchanged, so it drops
# again; upstream lyra ships NO button-group orientation rules (its
# children are all square already) - poetry's collapse machinery keeps
# working with caps subbed to rounded-none; drawer directions get
# rounded-none theme-side (poetry-own surfaces adapting the theme);
# upstream's accordion focus story is complete (ring-1 + after:border),
# so no poetry focus cluster is added - only the icon trio moves to
# poetry's own icon rule.

BACKDROP = "backdrop:bg-black/10 supports-backdrop-filter:backdrop:backdrop-blur-xs"

AA_DESTRUCTIVE85 = "text-[oklch(from_var(--destructive)_calc(l*0.85)_c_h)]"

PLAN = {
  # --- alert: poetry's 0-col grid idiom carries; lyra skin lands on it ---
  "cn-alert" =>
    "grid grid-cols-[0_1fr] items-start gap-0.5 rounded-none border px-2.5 py-2 text-left text-xs " \
    "has-data-[slot=alert-action]:relative has-data-[slot=alert-action]:pr-18 " \
    "has-[>svg]:grid-cols-[auto_1fr] has-[>svg]:gap-x-2 " \
    "[&>svg]:size-4 [&>svg]:translate-y-0 [&>svg]:text-current",
  "cn-alert-title" => "col-start-2 font-medium",
  "cn-alert-description" =>
    "col-start-2 text-xs/relaxed text-muted-foreground text-balance md:text-pretty [&_p:not(:last-child)]:mb-2",

  # --- alert dialog: flat ring-only, faint scrim --------------------------
  "cn-alert-dialog-content" =>
    "w-full max-w-[calc(100%-2rem)] bg-popover text-popover-foreground ring-foreground/10 " \
    "gap-4 rounded-none p-4 ring-1 duration-100 data-[size=default]:max-w-xs data-[size=sm]:max-w-xs " \
    "data-[size=default]:sm:max-w-sm #{BACKDROP} data-open:animate-in data-open:fade-in-0 " \
    "data-open:zoom-in-95",
  "cn-alert-dialog-header" => "gap-1.5",
  "cn-alert-dialog-media" => :default,
  "cn-alert-dialog-title" => "text-sm font-medium",

  # --- accordion: NO box (lyra ships none - the W2 carrier stays default);
  #     upstream's focus story is complete (ring-1 + after:border-ring), so
  #     only the icon trio moves to poetry's own icon rule ----------------
  "cn-accordion-trigger" =>
    { base: :upstream,
      drop: %w[**:data-[slot=accordion-trigger-icon]:text-muted-foreground
               **:data-[slot=accordion-trigger-icon]:ml-auto
               **:data-[slot=accordion-trigger-icon]:size-4] },
  "cn-accordion-trigger-icon" => "ml-auto size-4 text-muted-foreground",

  # --- kept-default (poetry anatomy / continuity; see ledger) ------------
  "cn-avatar-badge" => :default,
  "cn-calendar" => :default,
  "cn-combobox-trigger" => :default,
  "cn-switch-thumb" => :default,

  # --- drawer swipe handle: poetry-speak version of lyra's slim square
  #     bar (upstream restates anatomy in swipe-axis vocab poetry never
  #     stamps; the visual deltas port as plain after: tokens) ------------
  "cn-drawer-swipe-handle" =>
    { base: :default, sub: { "after:rounded-full" => "after:rounded-none",
                             "after:h-1.5" => "after:h-1",
                             "after:w-[100px]" => "after:w-12" } },

  # --- button-group end caps: upstream lyra ships no orientation rules
  #     (all children already square), so these names are poetry-only at
  #     this theme and need explicit bodies - poetry's collapse machinery
  #     verbatim with the caps squared (bangs are the default-inherited
  #     precedent) ----------------------------------------------------------
  "cn-button-group-orientation-horizontal" =>
    "*:data-slot:rounded-r-none [&>[data-slot]:not(:has(~[data-slot]))]:rounded-none! " \
    "[&>[data-slot]~[data-slot]]:rounded-l-none [&>[data-slot]~[data-slot]]:border-l-0",
  "cn-button-group-orientation-vertical" =>
    "flex-col *:data-slot:rounded-b-none [&>[data-slot]:not(:has(~[data-slot]))]:rounded-none! " \
    "[&>[data-slot]~[data-slot]]:rounded-t-none [&>[data-slot]~[data-slot]]:border-t-0",

  # --- buttons: lyra sizes + the >svg:first/last-child icon-side twins ---
  "cn-button-size-default" =>
    "h-8 gap-1.5 px-2.5 has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2 " \
    "has-[>svg:first-child]:pl-2 has-[>svg:last-child]:pr-2",
  "cn-button-size-xs" =>
    "h-6 gap-1 rounded-none px-2 text-xs has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 " \
    "has-[>svg:first-child]:pl-1.5 has-[>svg:last-child]:pr-1.5 [&_svg:not([class*='size-'])]:size-3",
  "cn-button-size-sm" =>
    "h-7 gap-1 rounded-none px-2.5 has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 " \
    "has-[>svg:first-child]:pl-1.5 has-[>svg:last-child]:pr-1.5 [&_svg:not([class*='size-'])]:size-3.5",
  "cn-button-size-lg" =>
    "h-9 gap-1.5 px-2.5 has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2 " \
    "has-[>svg:first-child]:pl-2 has-[>svg:last-child]:pr-2",

  # --- soft destructive, AA-held (posture; maia's exact body) ------
  "cn-button-variant-destructive" =>
    "bg-destructive/10 hover:bg-destructive/20 focus-visible:ring-destructive/20 " \
    "dark:focus-visible:ring-destructive/40 dark:bg-destructive/20 " \
    "#{AA_DESTRUCTIVE85} dark:text-destructive " \
    "focus-visible:border-destructive/40 dark:hover:bg-destructive/30",
  "cn-badge-variant-destructive" =>
    "bg-destructive/10 [a]:hover:bg-destructive/20 " \
    "#{AA_DESTRUCTIVE85} dark:text-destructive dark:bg-destructive/20",

  # --- badge: square chip, focus machinery dropped by upstream -----------
  "cn-badge" =>
    "h-5 gap-1 rounded-none border border-transparent px-2 py-0.5 text-xs font-medium transition-all " \
    "has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 " \
    "has-[>svg:first-child]:pl-1.5 has-[>svg:last-child]:pr-1.5 [&>svg]:size-3",

  "cn-checkbox" => { base: :upstream, drop: %w[group-has-disabled/field:opacity-50] },

  # --- command: poetry keeps structural gap + placeholder color; lyra's
  #     command-input-group box is a dropped upstream-only surface, so its
  #     pl-2 lands as wrapper px-2 (judged) --------------------------------
  "cn-command-input-wrapper" => "gap-2 border-b px-2 pb-0",
  "cn-command-input" => "w-full bg-transparent text-xs placeholder:text-muted-foreground",
  "cn-command-group" =>
    { base: :upstream, drop: %w[**:[[cmdk-group-heading]]:text-muted-foreground **:[[cmdk-group-heading]]:px-2
                                **:[[cmdk-group-heading]]:py-1.5 **:[[cmdk-group-heading]]:text-xs] },

  # --- dialog / sheet / sidebar-mobile (flat: no shadow anywhere); the
  #     bare `grid` display token is dropped so the native <dialog> closed
  #     state survives (the W3 rule) ---------------------------------------
  "cn-dialog-content" =>
    "w-full max-w-[calc(100%-2rem)] bg-popover text-popover-foreground ring-foreground/10 " \
    "gap-4 rounded-none p-4 text-xs/relaxed ring-1 duration-100 sm:max-w-sm #{BACKDROP} " \
    "data-open:animate-in data-open:fade-in-0 data-open:zoom-in-95",
  "cn-sheet-content" =>
    "m-0 w-full bg-popover text-popover-foreground text-xs/relaxed bg-clip-padding " \
    "transition duration-200 ease-in-out data-open:animate-in data-closed:animate-out #{BACKDROP}",
  "cn-sidebar-mobile" =>
    "bg-sidebar p-0 text-sidebar-foreground transition duration-200 ease-in-out " \
    "data-open:animate-in data-closed:animate-out #{BACKDROP}",

  # --- drawer: no floating frame (that is luma's); square panel, borders
  #     per side via poetry's own direction rules --------------------------
  "cn-drawer-content" => "bg-popover text-popover-foreground text-xs/relaxed",
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
  "cn-menubar-item-indicator" => "left-1.5 size-4 [&_svg:not([class*='size-'])]:size-4",
  # Separator structure (h-px + margins) is poetry's, theme-side; upstream
  # lyra's rule is color-only (bg-border) and would gut the divider.
  "cn-menubar-separator" => "-mx-1 my-1 h-px bg-border",

  "cn-combobox-content" =>
    "bg-popover text-popover-foreground ring-foreground/10 " \
    "*:data-[slot=input-group]:bg-input/30 *:data-[slot=input-group]:border-input/30 " \
    "*:data-[slot=input-group]:m-1 *:data-[slot=input-group]:mb-0 *:data-[slot=input-group]:h-8 " \
    "*:data-[slot=input-group]:shadow-none max-h-72 min-w-36 overflow-hidden rounded-none p-0 " \
    "shadow-md ring-1 duration-100 data-open:animate-in data-open:fade-in-0 data-open:zoom-in-95 " \
    "data-closed:animate-out data-closed:fade-out-0 data-closed:zoom-out-95 " \
    "data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 " \
    "data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2",

  # --- poetry's indicator is an svg dot -> fill idiom (lyra fills the
  #     checked item bg-primary, so the dot flips to primary-foreground) --
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
  "cn-toggle" => { base: :upstream, sub: { "data-[state=on]:bg-muted" => "data-pressed:bg-muted" } },
  "cn-table-row" =>
    "border-b transition-colors hover:bg-muted/50 has-aria-expanded:bg-muted/50 data-selected:bg-muted",

  # --- tabs: poetry's full active/line machinery, lyra geometry (the
  #     whole-cluster discipline; upstream's active state lives inline in
  #     its base component, theme-side in poetry) --------------------------
  "cn-tabs-trigger" =>
    "gap-1.5 rounded-none border border-transparent px-1.5 py-0.5 text-xs font-medium text-foreground/60 " \
    "hover:text-foreground has-data-[icon=inline-end]:pr-1 has-data-[icon=inline-start]:pl-1 " \
    "dark:text-muted-foreground dark:hover:text-foreground " \
    "group-data-[variant=default]/tabs-list:data-active:shadow-sm " \
    "group-data-[variant=line]/tabs-list:data-active:shadow-none [&_svg:not([class*='size-'])]:size-4 " \
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
    "group-data-vertical/tabs:py-[calc(--spacing(1.25))]",

  # --- toggle group: item-scoped translation of upstream's group-scoped
  #     spacing cluster; whole radius cluster theme-side (the W2 lesson) --
  "cn-toggle-group-item" =>
    "data-[spacing=0]:rounded-none data-[spacing=0]:px-2 " \
    "data-[spacing=0]:has-data-[icon=inline-end]:pr-1.5 data-[spacing=0]:has-data-[icon=inline-start]:pl-1.5 " \
    "data-[spacing=0]:first:rounded-none data-[spacing=0]:last:rounded-none",

  "cn-toggle-size-default" =>
    "h-8 min-w-8 px-2.5 has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2 " \
    "has-[>svg:first-child]:pl-2 has-[>svg:last-child]:pr-2",
  "cn-toggle-size-sm" =>
    "h-7 min-w-7 rounded-none px-2.5 has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 " \
    "has-[>svg:first-child]:pl-1.5 has-[>svg:last-child]:pr-1.5",
  "cn-toggle-size-lg" =>
    "h-9 min-w-9 px-2.5 has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2 " \
    "has-[>svg:first-child]:pl-2 has-[>svg:last-child]:pr-2",

  "cn-attachment-media" =>
    { base: :upstream, sub: { "group-data-[orientation=vertical]/attachment:*:data-[slot=spinner]:size-6!" =>
                              "group-data-[orientation=vertical]/attachment:*:data-[slot=spinner]:size-6" } },

  # --- poetry-own toast family: upstream's rule is a delta over its own
  #     sonner base - poetry keeps the full default body, radius squared --
  "cn-toast" => { base: :default, sub: { "rounded-md" => "rounded-none" } },

  # --- form controls: untinted square fields; the placeholder token
  #     returns with the W2 side-move (upstream omits it) ------------------
  "cn-input" => { base: :upstream, add: %w[placeholder:text-muted-foreground] },
  "cn-textarea" => { base: :upstream, add: %w[placeholder:text-muted-foreground] },

  # --- the parse-quirk repair: cn-bubble transcribed from the raw
  #     fragment (see header note) -----------------------------------------
  "cn-bubble" =>
    "gap-1 data-[align=end]:self-end max-w-[80%] data-[variant=ghost]:max-w-full " \
    "group-data-[align=end]/message:self-end"
}.freeze

HEADER = <<~CSS
  /* poetry lyra theme (N12 W4) - upstream style-lyra.css ported onto the
   * cn-* layer (pinned clone d0fae528). Same contract as default.css:
   * imported layer(base); bare selectors while installs carry ONE theme;
   * rule order per component = base < elements < variants < compounds;
   * split-side, no-empty-rules and cross-component-last rules apply.
   *
   * Port disciplines identical to vega/rhea (see the N12 plan note
   * close-outs + docs/lyra-port-ledger.txt): verbatim where poetry
   * speaks the vocabulary; data-vertical -> data-[orientation=*];
   * data-[state=on] -> data-pressed; overlays -> native-dialog
   * backdrop:* (black/10 blur-xs - the faintest scrim of the series);
   * upstream ! stripped except the sidebar collapse geometry and
   * default-inherited precedents; icon paddings ship upstream's
   * has-data-[icon=*] (inert) plus working >svg:first/last-child twins;
   * soft destructive holds AA via relative-oklch light-mode darkening
   * (posture). Lyra-specific: rounded-none universal with the
   * whole type scale one step down (text-xs bodies), ring-1 focus
   * temperature, muted-based hovers, right-side menu indicators, filled
   * radios (dot flips to fill-primary-foreground), press-nudge buttons,
   * --card-spacing var cards on ring-foreground/10, flat sheets (no
   * shadow), button-group caps squared over poetry's collapse
   * machinery, and NO AA kit beyond the destructive pair: lyra's tints
   * are disabled fills (WCAG-exempt) and /30 dropdown search boxes (the
   * maia class). Fonts move via size/weight/tracking utilities only -
   * the mono-family pairing is upstream create-flow metadata, told in
   * docs, not CSS. Upstream parse quirk ledgered: style-lyra.css:1358
   * lacks a semicolon (cn-menu-translucent), so cn-bubble ships as an
   * explicit transcribed value.
   */
CSS
