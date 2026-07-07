---
version: alpha
name: poetry default
description: poetry default - semantic role tokens (shared across every poetry theme)
  under the default component treatment.
colors:
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
modes:
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
typography:
  body:
    fontFamily: ui-sans-serif, system-ui, sans-serif
rounded:
  sm: 6px
  md: 8px
  lg: 10px
  xl: 14px
  2xl: 18px
  3xl: 22px
  4xl: 26px
poetry:
  theme: default
  source: tokens/tokens.dtcg.json
  generator: bin/rails poetry:design:export
  dark_mode: class.dark
  radius: 0.625rem
  radius_scale:
    sm: calc(var(--radius) * 0.6)
    md: calc(var(--radius) * 0.8)
    lg: var(--radius)
    xl: calc(var(--radius) * 1.4)
    2xl: calc(var(--radius) * 1.8)
    3xl: calc(var(--radius) * 2.2)
    4xl: calc(var(--radius) * 2.6)
  typography_pairing: system sans
  treatment: the neutral shadcn-parity treatment (new-york-v4 baseline)
  components_count: 65
  components_pointer: "/poetry/llms.txt"
  contrast_policy:
    floor: WCAG 2.2 AA (4.5:1) - locked, every gated pair
    target: AAA (7:1) wherever achievable at lock time
    gate: Poetry::Core::Tokens::ContrastGate
    aa_exceptions:
    - "[light] muted-foreground on muted: 4.54:1 (locked AA, needs >= 4.5)"
    - "[light] muted-foreground on background: 4.96:1 (locked AA, needs >= 4.5)"
    - "[light] white on destructive: 4.76:1 (locked AA, needs >= 4.5)"
    - "[dark] muted-foreground on muted: 5.83:1 (locked AA, needs >= 4.5)"
    - "[dark] white on destructive/60% over background: 6.48:1 (locked AA, needs >=
      4.5)"
    - "[dark] sidebar-primary-foreground on sidebar-primary: 6.54:1 (locked AA, needs
      >= 4.5)"
---
# DESIGN.md - poetry default

poetry default - semantic role tokens (shared across every poetry theme) under the default component treatment.

## Overview

- design system: poetry - server-rendered Rails components (ViewComponent + Stimulus + Tailwind v4)
- theme: default - the neutral shadcn-parity treatment (new-york-v4 baseline)
- token source: one DTCG file shared by every poetry theme (`tokens/tokens.dtcg.json`);
  themes are component-treatment layers, not palettes
- dark mode: the `.dark` class - both modes ship in this file

## Colors

Semantic roles only - components never reference raw palette values
(the class verifier and `poetry check` enforce this).

| role | light | dark |
|---|---|---|
| background | oklch(1 0 0) | oklch(0.145 0 0) |
| foreground | oklch(0.145 0 0) | oklch(0.985 0 0) |
| card | oklch(1 0 0) | oklch(0.205 0 0) |
| card-foreground | oklch(0.145 0 0) | oklch(0.985 0 0) |
| popover | oklch(1 0 0) | oklch(0.205 0 0) |
| popover-foreground | oklch(0.145 0 0) | oklch(0.985 0 0) |
| primary | oklch(0.205 0 0) | oklch(0.922 0 0) |
| primary-foreground | oklch(0.985 0 0) | oklch(0.205 0 0) |
| secondary | oklch(0.97 0 0) | oklch(0.269 0 0) |
| secondary-foreground | oklch(0.205 0 0) | oklch(0.985 0 0) |
| muted | oklch(0.97 0 0) | oklch(0.269 0 0) |
| muted-foreground | oklch(0.545 0 0) | oklch(0.708 0 0) |
| accent | oklch(0.97 0 0) | oklch(0.269 0 0) |
| accent-foreground | oklch(0.205 0 0) | oklch(0.985 0 0) |
| destructive | oklch(0.577 0.245 27.325) | oklch(0.704 0.191 22.216) |
| border | oklch(0.922 0 0) | oklch(1 0 0 / 10%) |
| input | oklch(0.922 0 0) | oklch(1 0 0 / 15%) |
| ring | oklch(0.708 0 0) | oklch(0.556 0 0) |
| chart-1 | oklch(0.809 0.105 251.813) | oklch(0.809 0.105 251.813) |
| chart-2 | oklch(0.623 0.214 259.815) | oklch(0.623 0.214 259.815) |
| chart-3 | oklch(0.546 0.245 262.881) | oklch(0.546 0.245 262.881) |
| chart-4 | oklch(0.488 0.243 264.376) | oklch(0.488 0.243 264.376) |
| chart-5 | oklch(0.424 0.199 265.638) | oklch(0.424 0.199 265.638) |
| sidebar | oklch(0.985 0 0) | oklch(0.205 0 0) |
| sidebar-foreground | oklch(0.145 0 0) | oklch(0.985 0 0) |
| sidebar-primary | oklch(0.205 0 0) | oklch(0.488 0.243 264.376) |
| sidebar-primary-foreground | oklch(0.985 0 0) | oklch(0.985 0 0) |
| sidebar-accent | oklch(0.97 0 0) | oklch(0.269 0 0) |
| sidebar-accent-foreground | oklch(0.205 0 0) | oklch(0.985 0 0) |
| sidebar-border | oklch(0.922 0 0) | oklch(1 0 0 / 10%) |
| sidebar-ring | oklch(0.708 0 0) | oklch(0.556 0 0) |

## Typography

- pairing: system sans (app-level metadata - no poetry theme
  moves a font token;)
- family: ui-sans-serif, system-ui, sans-serif

## Layout

- spacing: the Tailwind v4 default scale (0.25rem base unit) - poetry adds no spacing tokens
- structure: components size to their container; page layout stays host-owned

## Elevation & Depth

- shadows and overlay scrims are theme treatment (the `cn-*` layer), not tokens -
  default ships its own elevation story

## Shapes

- radius: 0.625rem (`--radius`)
- scale: sm calc(var(--radius) * 0.6) - md calc(var(--radius) * 0.8) - lg var(--radius) - xl calc(var(--radius) * 1.4) - 2xl calc(var(--radius) * 1.8) - 3xl calc(var(--radius) * 2.2) - 4xl calc(var(--radius) * 2.6)

## Components

- catalog: 65 components - the registry is the truth; read
  `/poetry/llms.txt` (or `llms-full.txt` with events and variants)
  instead of duplicating it here
- consume via `poetry_*` helpers; styling rides the theme's `cn-*` classes,
  never per-instance CSS

## Do's and Don'ts

- Do pick variants by intent - one `primary` action per view; `destructive`
  only for irreversible actions.
- Do keep both modes honest - every surface must hold in light and dark.
- Don't hand-write hex/oklch in markup - use role tokens (`bg-primary`,
  `text-destructive`, ...); `poetry check` flags raw color classes.
- Don't paint white text on solid `destructive` in dark mode - dark
  destructive renders at 60% over the background.
- Don't introduce new colors, shadows, or radii without adding tokens first.
