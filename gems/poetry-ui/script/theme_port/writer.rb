# frozen_string_literal: true

#
# theme-port tooling (banked from the vega run - see
# docs/vega-port-ledger.txt). SUPERSEDED: the ledgers are retired -
# deviations live in config/theme_fidelity/deviations.yml under the
# css:verify_fidelity gate.
# For the NEXT port (nova/mira/rhea): point the upstream path at the new
# style-<name>.css, re-run the detector for the diff/conflict report, then
# author a fresh PLAN in a copy of the writer. NOTE: the writer is a
# ONE-SHOT generator - themes/vega.css is canonical and has been hand-
# edited since generation (AA-hold comments); never regenerate over it.
# Emits Code/poetry-ui/themes/vega.css from default.css structure +
# the vega translation plan. Mechanical rule: shared-diff names adopt the
# upstream vega body minus tokens already in poetry's inline set; PLAN
# entries override where poetry's anatomy/idiom demands judgment. Also
# writes the ledger (per-part status) consumed by the close-out + the
# judged comparison pass.

require "json"

DIR = __dir__
UI = File.expand_path("../..", __dir__)
parts = JSON.parse(File.read(File.join(DIR, "parts.json")))
SHARED = parts["shared"]
default_text = File.read(File.join(UI, "themes/default.css"))

# ---------------------------------------------------------------------------
# The plan. keys: cn name; values:
#   :default          -> keep poetry's default body (poetry-own idiom/anatomy)
#   :mechanical       -> vega body minus inline dups (also the fallback)
#   String            -> explicit body (judged)
#   {sub:{from=>to}, drop:[...], add:[...], base: :vega|:default}
# ---------------------------------------------------------------------------
BACKDROP = "backdrop:bg-black/10 supports-backdrop-filter:backdrop:backdrop-blur-xs"

PLAN = {
  # --- alert: poetry's 0-col grid idiom carries; vega skin lands on it ----
  "cn-alert" =>
    "grid grid-cols-[0_1fr] items-start gap-0.5 rounded-lg border px-4 py-3 text-left text-sm " \
    "has-data-[slot=alert-action]:relative has-data-[slot=alert-action]:pr-18 " \
    "has-[>svg]:grid-cols-[calc(var(--spacing)*4)_1fr] has-[>svg]:gap-x-2.5 " \
    "[&>svg]:size-4 [&>svg]:translate-y-0.5 [&>svg]:text-current",
  "cn-alert-title" => "col-start-2 font-medium",
  "cn-alert-description" =>
    "col-start-2 text-sm text-muted-foreground text-balance md:text-pretty [&_p:not(:last-child)]:mb-4",

  # --- alert dialog: native <dialog> (backdrop:*), server-side size/media
  #     branches carry the conditional layout - theme rules stay flat ------
  "cn-alert-dialog-content" =>
    "w-full max-w-[calc(100%-2rem)] bg-popover text-popover-foreground ring-foreground/10 gap-6 " \
    "rounded-xl p-6 ring-1 duration-100 data-[size=default]:max-w-xs data-[size=sm]:max-w-xs " \
    "data-[size=default]:sm:max-w-lg #{BACKDROP} data-open:animate-in data-open:fade-in-0 " \
    "data-open:zoom-in-95",
  "cn-alert-dialog-header" => "gap-1.5",
  "cn-alert-dialog-media" => :default,
  "cn-alert-dialog-title" => "text-lg font-medium",

  # --- accordion: icon styling lives on poetry's own icon hook -----------
  "cn-accordion-trigger" =>
    { base: :vega, drop: %w[**:data-[slot=accordion-trigger-icon]:text-muted-foreground
                            **:data-[slot=accordion-trigger-icon]:ml-auto
                            **:data-[slot=accordion-trigger-icon]:size-4] },
  "cn-accordion-trigger-icon" => "ml-auto size-4 text-muted-foreground",

  # --- kept-default (poetry anatomy / continuity; see ledger) ------------
  "cn-avatar-badge" => :default, # vega ships no size chains; poetry keeps sized badges
  "cn-button-group-orientation-horizontal" => :default, # collapse mechanism (vega text incomplete alone)
  "cn-button-group-orientation-vertical" => :default,
  "cn-calendar" => :default,                   # poetry-own engine: calendar family inherits default
  "cn-combobox-trigger" => :default,           # poetry trigger is its own box; vega's is a Button
  "cn-drawer-swipe-handle" => :default,        # poetry-own geometry (no drawer-popup group)
  "cn-switch-thumb" => :default,               # equivalent to vega per-size split + keeps rtl mirror
  "cn-tabs-trigger" => :default,               # color cluster is theme-side in poetry (split-side rule)

  # --- buttons: vega sizes + the >svg:first/last-child icon-side twins ---
  "cn-button-size-default" =>
    "h-9 gap-1.5 px-2.5 in-data-[slot=button-group]:rounded-md has-data-[icon=inline-end]:pr-2 " \
    "has-data-[icon=inline-start]:pl-2 has-[>svg:first-child]:pl-2 has-[>svg:last-child]:pr-2",
  "cn-button-size-xs" =>
    "h-6 gap-1 rounded-[min(var(--radius-md),8px)] px-2 text-xs in-data-[slot=button-group]:rounded-md " \
    "has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 " \
    "has-[>svg:first-child]:pl-1.5 has-[>svg:last-child]:pr-1.5 [&_svg:not([class*='size-'])]:size-3",
  "cn-button-size-sm" =>
    "h-8 gap-1 rounded-[min(var(--radius-md),10px)] px-2.5 in-data-[slot=button-group]:rounded-md " \
    "has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 " \
    "has-[>svg:first-child]:pl-1.5 has-[>svg:last-child]:pr-1.5",
  "cn-button-size-lg" =>
    "h-10 gap-1.5 px-2.5 has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2 " \
    "has-[>svg:first-child]:pl-2 has-[>svg:last-child]:pr-2",

  # --- soft destructive, AA-held (light darkens text via relative oklch,
  #     dark restores the token) - documented deviation, AA-contrast posture ----
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

  # --- badge: pill + soft destructive; svg-size bang stripped (policy) ---
  "cn-badge" =>
    "h-5 gap-1 rounded-4xl border border-transparent px-2 py-0.5 text-xs font-medium transition-all " \
    "has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 " \
    "has-[>svg:first-child]:pl-1.5 has-[>svg:last-child]:pr-1.5 [&>svg]:size-3",

  "cn-checkbox" => { base: :vega, drop: %w[group-has-disabled/field:opacity-50] },

  # --- command: poetry single-wrapper anatomy approximates vega's boxed
  #     input-group; importants stripped (closing-section order suffices) --
  "cn-command" => "bg-popover text-popover-foreground rounded-xl p-1",
  "cn-command-input-wrapper" =>
    "m-1 mb-0 h-8 gap-2 rounded-lg border border-input/30 bg-input/30 px-2 shadow-none",
  "cn-command-input" => "w-full bg-transparent text-sm placeholder:text-muted-foreground",
  "cn-command-item" =>
    { base: :vega, sub: { "in-data-[slot=dialog-content]:rounded-lg!" => "in-data-[slot=dialog-content]:rounded-lg" } },
  "cn-command-group" =>
    { base: :vega, drop: %w[**:[[cmdk-group-heading]]:text-muted-foreground **:[[cmdk-group-heading]]:px-2
                            **:[[cmdk-group-heading]]:py-1.5 **:[[cmdk-group-heading]]:text-xs
                            **:[[cmdk-group-heading]]:font-medium] },

  # --- dialog / sheet / sidebar-mobile: native-dialog mechanism residue
  #     (w-full, m-0, open-anims, backdrop:*) + vega's popover skin --------
  "cn-dialog-content" =>
    "w-full max-w-[calc(100%-2rem)] bg-popover text-popover-foreground ring-foreground/10 gap-6 " \
    "rounded-xl p-6 text-sm ring-1 duration-100 sm:max-w-md #{BACKDROP} data-open:animate-in " \
    "data-open:fade-in-0 data-open:zoom-in-95",
  "cn-sheet-content" =>
    "m-0 w-full gap-4 bg-popover text-popover-foreground text-sm bg-clip-padding shadow-lg " \
    "transition duration-200 ease-in-out data-open:animate-in data-closed:animate-out #{BACKDROP}",
  "cn-sidebar-mobile" =>
    "bg-sidebar p-0 text-sidebar-foreground shadow-lg transition duration-200 ease-in-out " \
    "data-open:animate-in data-closed:animate-out #{BACKDROP}",

  # --- drawer: poetry per-direction rules carry geometry; content takes
  #     vega's surface; header follows vega (text-center dropped) ---------
  "cn-drawer-content" => "bg-popover text-sm text-popover-foreground",
  "cn-drawer-header" => "gap-0.5 p-4 pb-0 md:gap-1.5 md:text-left",
  "cn-drawer-footer" => :default,

  # --- menus: sub-trigger open-state augmented with poetry's stamped
  #     data-popup-open (vega's data-open kept verbatim alongside) --------
  "cn-dropdown-menu-sub-trigger" =>
    { base: :vega, add: %w[data-popup-open:bg-accent data-popup-open:text-accent-foreground] },
  "cn-context-menu-sub-trigger" =>
    { base: :vega, add: %w[data-popup-open:bg-accent data-popup-open:text-accent-foreground] },
  "cn-menubar-sub-trigger" =>
    { base: :vega, add: %w[data-popup-open:bg-accent data-popup-open:text-accent-foreground] },
  # poetry's one-word subcontent name carries vega's full sub-content box
  "cn-context-menu-subcontent" => :vega_sub_content,
  "cn-menubar-item-indicator" => "left-2 size-4 [&_svg:not([class*='size-'])]:size-4",

  "cn-combobox-content" =>
    "bg-popover text-popover-foreground ring-foreground/10 max-h-72 min-w-36 overflow-hidden " \
    "rounded-md p-0 shadow-md ring-1 duration-100 data-open:animate-in data-open:fade-in-0 " \
    "data-open:zoom-in-95 data-closed:animate-out data-closed:fade-out-0 data-closed:zoom-out-95 " \
    "data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 " \
    "data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2",

  # --- radio: poetry's indicator is an svg dot - vega's white-on-primary
  #     look lands as fill-primary-foreground -----------------------------
  "cn-radio-group-indicator-icon" => "size-2 fill-primary-foreground",

  # --- vocabulary translations -------------------------------------------
  "cn-slider" => { base: :vega, sub: { "data-vertical:min-h-40" => "data-[orientation=vertical]:min-h-40" } },
  "cn-slider-track" =>
    { base: :vega, sub: {
      "data-horizontal:h-1.5" => "data-[orientation=horizontal]:h-1.5",
      "data-horizontal:w-full" => "data-[orientation=horizontal]:w-full",
      "data-vertical:h-full" => "data-[orientation=vertical]:h-full",
      "data-vertical:w-1.5" => "data-[orientation=vertical]:w-1.5"
    } },
  "cn-table-row" =>
    "border-b transition-colors hover:bg-muted/50 has-aria-expanded:bg-muted/50 data-selected:bg-muted",
  "cn-toggle-group" =>
    "rounded-md data-[spacing=0]:data-[variant=outline]:shadow-xs " \
    "data-[spacing=default]:data-[variant=outline]:shadow-xs",
  "cn-toggle-group-item" => "px-3 data-pressed:bg-muted data-[spacing=0]:px-2 data-[spacing=0]:shadow-none",

  # --- toggle sizes: vega paddings + icon-side twins ----------------------
  "cn-toggle-size-default" =>
    "h-9 min-w-9 px-2.5 has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2 " \
    "has-[>svg:first-child]:pl-2 has-[>svg:last-child]:pr-2",
  "cn-toggle-size-sm" =>
    "h-8 min-w-8 px-2.5 has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 " \
    "has-[>svg:first-child]:pl-1.5 has-[>svg:last-child]:pr-1.5",
  "cn-toggle-size-lg" =>
    "h-10 min-w-10 px-2.5 has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2 " \
    "has-[>svg:first-child]:pl-2 has-[>svg:last-child]:pr-2",

  "cn-tooltip-arrow" => "size-2.5 rounded-[2px]", # translate lives inline (spelling twin)

  "cn-attachment-media" =>
    { base: :vega, sub: { "group-data-[orientation=vertical]/attachment:*:data-[slot=spinner]:size-6!" =>
                          "group-data-[orientation=vertical]/attachment:*:data-[slot=spinner]:size-6" } },

  # --- poetry-own toast family: vega's sonner delta is the 2xl radius ----
  "cn-toast" => { base: :default, sub: { "rounded-md" => "rounded-2xl" } }
}.freeze

def vega_body(name, parts_shared, plan_value)
  entry = parts_shared[name]
  case plan_value
  when nil
    return entry["rule"].join(" ") if entry && entry["status"] == "identical"
    return (entry["vega"] - entry["dup_inline"]).join(" ") if entry # mechanical

    nil # poetry-only, no plan -> keep default
  when String then plan_value
  when :default, :vega_sub_content then nil # vega_sub_content handled by caller
  when Hash
    base = if plan_value[:base] == :vega
             entry["vega"] - (entry["dup_inline"] || [])
           else
             entry["rule"] || entry["default"]
           end
    base = base ? base.dup : []
    base -= plan_value[:drop] if plan_value[:drop]
    base += plan_value[:add] if plan_value[:add]
    body = base.join(" ")
    (plan_value[:sub] || {}).each { |from, to| body = body.sub(from, to) }
    body
  end
end

# vega raw table for the transplants
VEGA_RAW = JSON.parse(File.read(File.join(DIR, "parts.json")))["vega_only"]

HEADER = <<~CSS
  /* poetry vega theme - upstream style-vega.css ported onto the
   * cn-* layer (pinned clone d0fae528). Same contract as default.css:
   * imported layer(base); bare selectors while installs carry ONE theme
   * (the .style-<name> wrapper arrives with the docs switcher); rule order
   * per component = base < elements < variants < compounds; split-side,
   * no-empty-rules and cross-component-last rules apply (see the default
   * theme header).
   *
   * Port disciplines (deviation receipts: config/theme_fidelity/deviations.yml):
   *   - upstream token text kept VERBATIM wherever poetry's markup speaks
   *     the same vocabulary; translated where it does not (data-[state=on]
   *     -> data-pressed, data-vertical -> data-[orientation=vertical],
   *     overlay rules -> native-dialog backdrop:* pseudos);
   *   - upstream !important stripped (layer order + closing-section order
   *     arbitrate; the sidebar collapse geometry keeps upstream's ! - the
   *     default-theme precedent);
   *   - icon-side paddings carry upstream's has-data-[icon=*] form (inert
   *     in poetry markup) PLUS working >svg:first/last-child twins;
   *   - native-dialog surfaces keep mechanism residue (m-0/w-full/open
   *     animations); display tokens never port onto <dialog> (open:grid
   *     stays inline - the class:nil lesson);
   *   - poetry-own surfaces (calendar engine, drawer geometry, tabs color
   *     cluster, combobox trigger box, toast family, link, data-table,
   *     charts) inherit the default treatment where vega ships no
   *     equivalent - each is ledgered.
   */
CSS

out = +""
out << HEADER << "\n"

mode = :copy
name = nil
skipped_header = false
default_text.each_line do |line| # rubocop:disable Metrics/BlockLength
  # drop default.css's own header comment (first comment block)
  unless skipped_header
    next if line.start_with?("/*", " *")

    skipped_header = true
    next if line.strip.empty?
  end

  case mode
  when :copy
    if (m = line.match(/\A\.(cn-[a-z0-9-]+)\s*\{\s*\z/))
      name = m[1]
      body = if PLAN[name] == :vega_sub_content
               base = name.sub("subcontent", "sub-content")
               VEGA_RAW[base].join(" ")
             else
               vega_body(name, SHARED, PLAN[name])
             end
      if body
        out << ".#{name} {\n  @apply #{body};\n}\n"
        mode = :skip_rule
      else
        out << line
        mode = :in_rule
      end
    else
      out << line
    end
  when :in_rule
    out << line
    mode = :copy if line.strip == "}"
  when :skip_rule
    mode = :copy if line.strip == "}"
  end
end

target = File.join(UI, "themes/vega.css")
File.write(target, out)
puts "wrote #{target} (#{out.lines.size} lines)"

# --- ledger ---------------------------------------------------------------
ledger = +"# vega translation ledger (generated by writer.rb)\n\n"
SHARED.sort.each do |n, e|
  status = if PLAN[n].is_a?(String) || PLAN[n].is_a?(Hash) || PLAN[n] == :vega_sub_content
             "judged"
           elsif PLAN[n] == :default
             "poetry-idiom (kept default)"
           elsif e["status"] == "identical"
             "identical"
           else
             "mechanical (vega minus inline dups)"
           end
  ledger << "#{n}: #{status}\n"
end
ledger << "\n## vega-only names (dropped; reason class)\n"
VEGA_RAW.keys.sort.each { |n| ledger << "#{n}: dropped\n" }
File.write(File.join(DIR, "ledger.txt"), ledger)
puts "ledger written"
