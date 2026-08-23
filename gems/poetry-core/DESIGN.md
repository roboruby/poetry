---
design_system: poetry
source: tokens/tokens.dtcg.json
generator: bin/rake tokens:generate
dark_mode: class .dark
radius: 0.625rem
radius_scale:
  radius-sm: calc(var(--radius) * 0.6)
  radius-md: calc(var(--radius) * 0.8)
  radius-lg: var(--radius)
  radius-xl: calc(var(--radius) * 1.4)
  radius-2xl: calc(var(--radius) * 1.8)
  radius-3xl: calc(var(--radius) * 2.2)
  radius-4xl: calc(var(--radius) * 2.6)
colors:
  light:
    background: oklch(1 0 0)
    foreground: oklch(0.145 0 0)
    card: oklch(1 0 0)
    card-foreground: oklch(0.145 0 0)
    popover: oklch(1 0 0)
    popover-foreground: oklch(0.145 0 0)
    primary: oklch(0.205 0 0)
    primary-foreground: oklch(0.985 0 0)
    secondary: oklch(0.97 0 0)
    secondary-foreground: oklch(0.205 0 0)
    muted: oklch(0.97 0 0)
    muted-foreground: oklch(0.545 0 0)
    accent: oklch(0.97 0 0)
    accent-foreground: oklch(0.205 0 0)
    destructive: oklch(0.577 0.245 27.325)
    success: oklch(0.596 0.145 163.225)
    warning: oklch(0.555 0.163 48.998)
    info: oklch(0.546 0.245 262.881)
    border: oklch(0.922 0 0)
    input: oklch(0.922 0 0)
    ring: oklch(0.708 0 0)
    chart-1: oklch(0.809 0.105 251.813)
    chart-2: oklch(0.623 0.214 259.815)
    chart-3: oklch(0.546 0.245 262.881)
    chart-4: oklch(0.488 0.243 264.376)
    chart-5: oklch(0.424 0.199 265.638)
    sidebar: oklch(0.985 0 0)
    sidebar-foreground: oklch(0.145 0 0)
    sidebar-primary: oklch(0.205 0 0)
    sidebar-primary-foreground: oklch(0.985 0 0)
    sidebar-accent: oklch(0.97 0 0)
    sidebar-accent-foreground: oklch(0.205 0 0)
    sidebar-border: oklch(0.922 0 0)
    sidebar-ring: oklch(0.708 0 0)
  dark:
    background: oklch(0.145 0 0)
    foreground: oklch(0.985 0 0)
    card: oklch(0.205 0 0)
    card-foreground: oklch(0.985 0 0)
    popover: oklch(0.205 0 0)
    popover-foreground: oklch(0.985 0 0)
    primary: oklch(0.922 0 0)
    primary-foreground: oklch(0.205 0 0)
    secondary: oklch(0.269 0 0)
    secondary-foreground: oklch(0.985 0 0)
    muted: oklch(0.269 0 0)
    muted-foreground: oklch(0.708 0 0)
    accent: oklch(0.269 0 0)
    accent-foreground: oklch(0.985 0 0)
    destructive: oklch(0.704 0.191 22.216)
    success: oklch(0.765 0.177 163.223)
    warning: oklch(0.828 0.189 84.429)
    info: oklch(0.809 0.105 251.813)
    border: oklch(1 0 0 / 10%)
    input: oklch(1 0 0 / 15%)
    ring: oklch(0.556 0 0)
    chart-1: oklch(0.809 0.105 251.813)
    chart-2: oklch(0.623 0.214 259.815)
    chart-3: oklch(0.546 0.245 262.881)
    chart-4: oklch(0.488 0.243 264.376)
    chart-5: oklch(0.424 0.199 265.638)
    sidebar: oklch(0.205 0 0)
    sidebar-foreground: oklch(0.985 0 0)
    sidebar-primary: oklch(0.488 0.243 264.376)
    sidebar-primary-foreground: oklch(0.985 0 0)
    sidebar-accent: oklch(0.269 0 0)
    sidebar-accent-foreground: oklch(0.985 0 0)
    sidebar-border: oklch(1 0 0 / 10%)
    sidebar-ring: oklch(0.556 0 0)
contrast_policy:
  floor: WCAG 2.2 AA (4.5:1) - locked, every gated pair
  target: AAA (7:1) wherever achievable at lock time
  gate: 'Poetry::Core::Tokens::ContrastGate (CI: rake test)'
  aa_exceptions:
  - "[light] muted-foreground on muted: 4.54:1 (locked AA, needs >= 4.5)"
  - "[light] muted-foreground on background: 4.96:1 (locked AA, needs >= 4.5)"
  - "[light] white on destructive: 4.76:1 (locked AA, needs >= 4.5)"
  - "[dark] muted-foreground on muted: 5.83:1 (locked AA, needs >= 4.5)"
  - "[dark] white on destructive/60% over background: 6.48:1 (locked AA, needs >=
    4.5)"
  - "[dark] sidebar-primary-foreground on sidebar-primary: 6.54:1 (locked AA, needs
    >= 4.5)"
parity:
  base: shadcn/ui v4 neutral (cssVarsV4 drop-in var set)
  deltas:
  - 'light muted-foreground: oklch(0.545 0 0) vs shadcn''s 0.556 - darkened to clear
    the locked WCAG AA floor (4.54:1 on muted, 4.96:1 on background; shadcn''s own
    value is 4.34:1 on muted, sub-AA).'
---

# DESIGN.md - the poetry design constitution

The front matter above is **generated** from `tokens/tokens.dtcg.json`
(`bin/rake tokens:generate`) and lists the exact tokens; this body is the
judgment layer - edit it freely, it is preserved across regenerations.

## Principles

- **Semantic roles only.** Components consume role tokens (`primary`,
  `destructive`, `muted`, `accent`, ...) - never raw palette values, never
  hex/oklch literals in markup (enforced by the class Verifier).
- **Both modes always.** Every surface must hold in light and dark; dark
  mode is the `.dark` class convention, and the contrast gate
  asserts every pair in both modes.
- **Contrast is law, not taste.** WCAG 2.2 AA is a locked floor; AAA is
  enforced where achievable. Exceptions are explicit (front matter) and
  reviewed - never silent.
- **Re-skin at the source.** Restyling the system means editing the DTCG
  tokens (or dropping in a shadcn v4 theme over `tokens/tokens.css`) and
  regenerating - one source, every surface.

## Do / Don't

- Do pick variants by intent (one `primary` action per view; `destructive`
  only for irreversible actions).
- Do keep borders subtle (`border`/`input` are deliberately low-contrast;
  they are not text and are not gated as text).
- Don't paint white text on solid `destructive` in dark mode - dark
  destructive surfaces are rendered at 60% over the background (2.9:1
  solid vs 6.5:1 composited).
- Don't introduce new colors, shadows, or radii without adding tokens
  here first.
