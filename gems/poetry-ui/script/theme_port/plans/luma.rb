# frozen_string_literal: true

# N12 W3 luma plan ("fluid, luminous, soft") for write_theme.rb. The
# soft-round luminous: rounded-4xl dialogs + rounded-3xl popovers with
# shadow-xl/lg over split ring temperature (ring-foreground/5 light, /10
# dark), rounded-2xl boxed accordion (the W2 carrier), rounded-full pill
# tabs, bg-input/50 borderless form surfaces (rhea's exact AA geometry -
# her full relative-oklch kit ships up front: placeholders 0.85, addon
# text 0.85, kbd/input-group-text 0.8, invalid-state counter-rules on
# the controls), /90 tinted checks/radios/switch/slider, pill switch
# thumb (w-6), black/30 blur-sm scrims (the luminous scrim), soft
# destructive (AA-held). NEW vs W2: the floating drawer before:-frame
# ships (deferred on mira/rhea as a taste-gap; it is luma's signature -
# pure-visual inset frame, upstream's bare `flex` dropped so the native
# <dialog> closed state survives, poetry's own sizing kept). Judged
# notes: accordion trigger gains poetry's focus cluster at luma's /30
# ring temperature; calendar keeps :default (poetry consumes --cell-size
# inline only; luma's 8 = poetry default - zero-cost defer);
# tabs-trigger ships poetry's full machinery with luma pill geometry,
# dark:data-active:border-input dropped (luma bangs borders transparent;
# honest drop instead of the ! - bang policy).

BACKDROP = "backdrop:bg-black/30 supports-backdrop-filter:backdrop:backdrop-blur-sm"

AA_MUTED85 = "text-[oklch(from_var(--muted-foreground)_calc(l*0.85)_c_h)]"
AA_MUTED8 = "text-[oklch(from_var(--muted-foreground)_calc(l*0.8)_c_h)]"
AA_DESTRUCTIVE85 = "text-[oklch(from_var(--destructive)_calc(l*0.85)_c_h)]"

PLAN = {
  # --- alert: poetry's 0-col grid idiom carries; luma skin lands on it ---
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
    "dark:ring-foreground/10 gap-6 rounded-4xl p-6 shadow-xl ring-1 duration-100 " \
    "data-[size=default]:max-w-xs data-[size=sm]:max-w-xs data-[size=default]:sm:max-w-md " \
    "#{BACKDROP} data-open:animate-in data-open:fade-in-0 data-open:zoom-in-95",
  "cn-alert-dialog-header" => "gap-1.5",
  "cn-alert-dialog-media" => :default,
  "cn-alert-dialog-title" => "text-lg font-medium",
  # (cn-alert-dialog-footer: luma does not band it - inherits default's gap-2)

  # --- accordion: the boxed root (the W2 carrier); poetry focus cluster
  #     added at luma's /30 ring temperature ------------------------------
  "cn-accordion" => "w-full overflow-hidden rounded-2xl border",
  "cn-accordion-trigger" =>
    { base: :upstream,
      drop: %w[**:data-[slot=accordion-trigger-icon]:text-muted-foreground
               **:data-[slot=accordion-trigger-icon]:ml-auto
               **:data-[slot=accordion-trigger-icon]:size-4],
      add: %w[focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/30] },
  "cn-accordion-trigger-icon" => "ml-auto size-4 text-muted-foreground",

  # --- kept-default (poetry anatomy / continuity; see ledger) ------------
  "cn-avatar-badge" => :default,
  "cn-calendar" => :default,
  "cn-combobox-trigger" => :default,
  "cn-drawer-swipe-handle" => :default,

  # --- button-group end caps: default bodies, luma 4xl caps --------------
  "cn-button-group-orientation-horizontal" =>
    { base: :default, sub: { "rounded-r-md!" => "rounded-r-4xl!" } },
  "cn-button-group-orientation-vertical" =>
    { base: :default, sub: { "rounded-b-md!" => "rounded-b-4xl!" } },

  # --- buttons: luma sizes + the >svg:first/last-child icon-side twins ---
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
    "#{AA_DESTRUCTIVE85} dark:text-destructive " \
    "focus-visible:border-destructive/40 dark:hover:bg-destructive/30",
  "cn-badge-variant-destructive" =>
    "bg-destructive/10 [a]:hover:bg-destructive/20 focus-visible:ring-destructive/20 " \
    "dark:focus-visible:ring-destructive/40 " \
    "#{AA_DESTRUCTIVE85} dark:text-destructive " \
    "dark:bg-destructive/20",

  # --- badge: luma 3xl pill; svg-size bang stripped (policy) -------------
  "cn-badge" =>
    "h-5 gap-1 rounded-3xl border border-transparent px-2 py-0.5 text-xs font-medium transition-all " \
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
    "dark:ring-foreground/10 gap-6 rounded-4xl p-6 text-sm shadow-xl ring-1 duration-100 " \
    "sm:max-w-md #{BACKDROP} data-open:animate-in data-open:fade-in-0 data-open:zoom-in-95",
  "cn-sheet-content" =>
    "m-0 w-full bg-popover text-popover-foreground text-sm bg-clip-padding shadow-xl " \
    "transition duration-200 ease-in-out data-open:animate-in data-closed:animate-out #{BACKDROP}",
  "cn-sidebar-mobile" =>
    "bg-sidebar p-0 text-sidebar-foreground shadow-xl transition duration-200 ease-in-out " \
    "data-open:animate-in data-closed:animate-out #{BACKDROP}",

  # --- drawer: the floating before:-frame ships (luma's signature; the
  #     W2 mira/rhea deferral was a taste-gap call, not a blocker).
  #     Upstream's bare `flex` and `h-auto` dropped: an unconditional
  #     display token would defeat the native <dialog> closed state
  #     (poetry inlines open:flex), and poetry keeps its own sizing. -----
  "cn-drawer-content" =>
    "bg-transparent p-4 text-sm before:absolute before:inset-2 before:-z-10 before:rounded-4xl " \
    "before:border before:border-border before:bg-popover before:shadow-xl",
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
    "bg-popover text-popover-foreground ring-foreground/5 dark:ring-foreground/10 max-h-72 min-w-36 " \
    "overflow-hidden rounded-3xl p-0 shadow-lg ring-1 duration-100 data-open:animate-in " \
    "data-open:fade-in-0 data-open:zoom-in-95 data-closed:animate-out data-closed:fade-out-0 " \
    "data-closed:zoom-out-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 " \
    "data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2",

  # --- poetry's indicator is an svg dot -> fill idiom ---------------------
  "cn-radio-group-indicator-icon" => "size-2 dark:size-2.5 fill-primary-foreground",

  # --- vocabulary translations -------------------------------------------
  "cn-slider" => { base: :upstream, sub: { "data-vertical:min-h-40" => "data-[orientation=vertical]:min-h-40" } },
  "cn-slider-track" =>
    { base: :upstream, sub: {
      "data-horizontal:h-2" => "data-[orientation=horizontal]:h-2",
      "data-horizontal:w-full" => "data-[orientation=horizontal]:w-full",
      "data-vertical:h-full" => "data-[orientation=vertical]:h-full",
      "data-vertical:w-2" => "data-[orientation=vertical]:w-2"
    } },
  "cn-slider-thumb" =>
    { base: :upstream, sub: {
      "data-vertical:h-6" => "data-[orientation=vertical]:h-6",
      "data-vertical:w-4" => "data-[orientation=vertical]:w-4"
    } },
  # luma's pill thumb travels its own geometry; poetry's rtl twin comes
  # along at the same 8px offset.
  "cn-switch-thumb" =>
    { base: :upstream, add: %w[rtl:data-checked:-translate-x-[calc(100%-8px)]] },
  "cn-table-row" =>
    "border-b transition-colors hover:bg-muted/50 has-aria-expanded:bg-muted/50 data-selected:bg-muted",

  # --- tabs: poetry's full active/line machinery, luma pill geometry;
  #     dark:data-active:border-input dropped (luma keeps borders
  #     transparent everywhere - upstream bangs it, we drop honestly) -----
  "cn-tabs-trigger" =>
    "gap-2 rounded-full border border-transparent px-3 py-1 text-sm font-medium text-foreground/60 " \
    "hover:text-foreground has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2 " \
    "dark:text-muted-foreground dark:hover:text-foreground " \
    "group-data-[variant=default]/tabs-list:data-active:shadow-sm " \
    "group-data-[variant=line]/tabs-list:data-active:shadow-none [&_svg:not([class*='size-'])]:size-4 " \
    "group-data-[variant=line]/tabs-list:bg-transparent " \
    "group-data-[variant=line]/tabs-list:data-active:bg-transparent " \
    "dark:group-data-[variant=line]/tabs-list:data-active:border-transparent " \
    "dark:group-data-[variant=line]/tabs-list:data-active:bg-transparent " \
    "data-active:bg-background data-active:text-foreground " \
    "dark:data-active:bg-input/30 after:bg-foreground group-data-horizontal/tabs:after:inset-x-0 " \
    "group-data-horizontal/tabs:after:bottom-[-5px] group-data-horizontal/tabs:after:h-0.5 " \
    "group-data-vertical/tabs:after:inset-y-0 group-data-vertical/tabs:after:-right-1 " \
    "group-data-vertical/tabs:after:w-0.5 " \
    "group-data-[variant=line]/tabs-list:data-active:after:opacity-100 " \
    "group-data-vertical/tabs:rounded-2xl group-data-vertical/tabs:px-3 group-data-vertical/tabs:py-1.5",

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

  # luma nudges the arrow horizontally per side (new x-vars compose with
  # the inline translate-y spelling twin via the shared --tw vars).
  "cn-tooltip-arrow" =>
    "size-2.5 rounded-[2px] data-[side=left]:translate-x-[-1.5px] data-[side=right]:translate-x-[1.5px]",

  "cn-attachment-media" =>
    { base: :upstream, sub: { "group-data-[orientation=vertical]/attachment:*:data-[slot=spinner]:size-6!" =>
                              "group-data-[orientation=vertical]/attachment:*:data-[slot=spinner]:size-6" } },

  # --- poetry-own toast family: upstream's rule is a delta over its own
  #     sonner base - poetry keeps the full default body, radius swapped --
  "cn-toast" => { base: :default, sub: { "rounded-md" => "rounded-2xl" } },

  # --- form controls on /50 tints: rhea's exact AA geometry, her full
  #     relative-oklch kit up front (every hold below was an axe-caught
  #     rhea failure; luma geometry, rhea holds) --------------------------
  "cn-input" =>
    "bg-input/50 border-transparent " \
    "placeholder:#{AA_MUTED85} dark:placeholder:text-muted-foreground " \
    "aria-invalid:#{AA_DESTRUCTIVE85} dark:aria-invalid:text-destructive " \
    "focus-visible:border-ring focus-visible:ring-ring/30 aria-invalid:ring-destructive/20 " \
    "dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive " \
    "dark:aria-invalid:border-destructive/50 h-9 rounded-3xl border px-3 py-1 text-base " \
    "transition-[color,box-shadow,background-color] file:h-7 file:text-sm file:font-medium " \
    "focus-visible:ring-3 aria-invalid:ring-3 md:text-sm",
  "cn-textarea" =>
    "bg-input/50 border-transparent " \
    "placeholder:#{AA_MUTED85} dark:placeholder:text-muted-foreground " \
    "aria-invalid:#{AA_DESTRUCTIVE85} dark:aria-invalid:text-destructive " \
    "focus-visible:border-ring focus-visible:ring-ring/30 aria-invalid:ring-destructive/20 " \
    "dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive " \
    "dark:aria-invalid:border-destructive/50 resize-none rounded-2xl border px-3 py-3 text-base " \
    "transition-[color,box-shadow,background-color] focus-visible:ring-3 aria-invalid:ring-3 md:text-sm",
  "cn-select-trigger" =>
    { base: :upstream, sub: { "data-placeholder:text-muted-foreground" =>
        "data-placeholder:text-[oklch(from_var(--muted-foreground)_calc(l*0.85)_c_h)] " \
        "dark:data-placeholder:text-muted-foreground" } },
  "cn-native-select" =>
    { base: :upstream, sub: { "placeholder:text-muted-foreground" =>
        "placeholder:text-[oklch(from_var(--muted-foreground)_calc(l*0.85)_c_h)] " \
        "dark:placeholder:text-muted-foreground" } },

  # --- input-group family on the /50 tint: addon text 0.85, kbd 0.8 via
  #     the scoped **: twin (wins by specificity over cn-kbd's own rule),
  #     group-text 0.8 own-rule (a child's own color rule beats inherited
  #     darkening - the rhea lesson) ---------------------------------------
  "cn-input-group-addon" =>
    "#{AA_MUTED85} dark:text-muted-foreground **:data-[slot=kbd]:bg-muted-foreground/10 " \
    "**:data-[slot=kbd]:#{AA_MUTED8} dark:**:data-[slot=kbd]:text-muted-foreground " \
    "h-auto gap-2 py-2 text-sm font-medium group-data-[disabled=true]/input-group:opacity-50 " \
    "**:data-[slot=kbd]:rounded-3xl **:data-[slot=kbd]:px-1.5 [&>svg:not([class*='size-'])]:size-4",
  "cn-input-group-text" =>
    "gap-2 text-sm #{AA_MUTED8} dark:text-muted-foreground [&_svg:not([class*='size-'])]:size-4"
}.freeze

HEADER = <<~CSS
  /* poetry luma theme (N12 W3) - upstream style-luma.css ported onto the
   * cn-* layer (pinned clone d0fae528). Same contract as default.css:
   * imported layer(base); bare selectors while installs carry ONE theme;
   * rule order per component = base < elements < variants < compounds;
   * split-side, no-empty-rules and cross-component-last rules apply.
   *
   * Port disciplines identical to vega/rhea (see the N12 plan note
   * close-outs + docs/luma-port-ledger.txt): verbatim where poetry
   * speaks the vocabulary; data-vertical -> data-[orientation=*];
   * data-[state=on] -> data-pressed; overlays -> native-dialog
   * backdrop:* (black/30 blur-sm - the luminous scrim); upstream !
   * stripped except the sidebar collapse geometry and default-inherited
   * precedents (luma's tabs border-transparent! becomes an honest drop
   * of the dark active border); icon paddings ship upstream's
   * has-data-[icon=*] (inert) plus working >svg:first/last-child twins.
   * Luma-specific: bg-input/50 borderless form surfaces carry rhea's
   * full AA kit (relative-oklch: placeholders/addons 0.85, kbd and
   * input-group-text 0.8 via scoped **: twins and own-rules,
   * aria-invalid counter-rules on the controls - posture); the
   * floating drawer before:-frame ships (upstream's bare `flex` dropped
   * so the native <dialog> closed state survives); pill switch thumb
   * travels 8px with poetry's rtl twin; boxed 2xl accordion root (the
   * W2 carrier) with poetry's focus cluster at /30 ring temperature.
   */
CSS
