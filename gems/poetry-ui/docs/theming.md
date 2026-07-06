# Theming poetry

How to restyle poetry components — from a color tweak to a full visual
system — without ever editing component source. The design lives in one
swappable stylesheet; everything else is contract.

## The three surfaces, cheapest first

1. **Tokens** (`poetry/tokens.css`): colors, radii, fonts as CSS custom
   properties (`--primary`, `--radius`, …). Editing tokens restyles every
   component at once and survives every upgrade. Dark mode is the `.dark`
   class flipping the same tokens.
2. **The theme layer** (`poetry/style-default.css`): every component's
   visual treatment as named `.cn-*` rules — `.cn-button`,
   `.cn-card-header`, `.cn-dialog-content`, each variant and size its own
   class (`.cn-button-variant-destructive`, `.cn-button-size-lg`).
   Shape, spacing, typography, shadows, animations per part.
3. **Per-instance utilities** (`class:` on any component): one-off tweaks
   at the call site, e.g. `poetry_button(class: "w-full")`.

## How the theme layer works

`poetry:install` imports the theme with **`layer(base)`**:

```css
@import "./poetry/style-default.css" layer(base);
```

Cascade layers do the heavy lifting — the rules that matter, in the order
they win:

- **Your utilities always beat the theme.** Anything in the Tailwind
  utilities layer (a `class:` argument, your own markup) outranks
  `layer(base)` regardless of specificity. `class: "rounded-none"` beats
  `.cn-button`'s `rounded-md`, always.
- **Your own CSS beats the theme too.** Any unlayered rule you write wins
  over `layer(base)`. Overriding a component is one plain rule:

  ```css
  /* application.css — no layer needed */
  .cn-card { border-radius: 0; box-shadow: none; }
  .cn-button-variant-default { background: black; }
  ```
- **Inside the theme, order is meaning.** Per component: base < elements
  < variants < compounds, so a variant's `hover:bg-accent` beats the
  base's `hover:bg-muted` the way the class merger used to. Cross-
  component overrides (e.g. `.cn-input-group-textarea` restyling a
  Textarea) sit in a closing section AFTER everything they override.
  Preserve both orders when editing a copy.

## Swapping the whole theme

`style-default.css` is vendored — a re-run of `poetry:install` refreshes
it, so upstream visual updates keep flowing. To own the design outright:

1. Copy `poetry/style-default.css` to e.g. `poetry/style-acme.css`.
2. Point the entry import at your copy (keep `layer(base)`).
3. Restyle freely — the markup never changes, because components emit
   stable `cn-*` names plus structural classes only.

The structural classes left in markup (layout, focus machinery, native
`<dialog>` guards, swipe/geometry vars) are the component's mechanism — a
theme can restyle every surface but can never break behavior.

## What stays out of the theme

- **Behavioral/structural classes** stay in markup (`inline-flex`,
  `open:grid`, `disabled:pointer-events-none`, popper vars, the slider's
  geometry chain). If removing a rule from the theme changes *behavior*,
  it was mechanism and lives in markup instead.
- **Machinery-only components** have no `cn-*` surface at all (their
  whole render is mechanism): AspectRatio, Separator, Spinner,
  ScrollArea, Carousel, Resizable, the chart Container. Restyle those via
  `data-slot` selectors or `class:`.
- **The chart palette** rides tokens (`--chart-1..5`), never the theme;
  series marks take `var(--color-<key>)` attributes. poetry-charts ships
  its chrome as `poetry/style-charts.css` (grid/tick/cursor/tooltip/
  legend rules shared across families).

## Consumer utilities

Two standalone classes the theme defines for direct use:

- `.cn-font-heading` — the heading-font hook: a no-op until you define
  `--font-heading` (falls back to `--font-sans`). Empty's title wears it;
  put it on any element that should follow the heading face.
- `.cn-rtl-flip` — mirrors an icon under RTL (`rtl:-scale-x-100`).
  Pagination and Breadcrumb chevrons wear it.

## Gates that keep a theme honest

- `rake css:verify_compiled` — every `cn-*` name a component emits must
  exist in the compiled build (a missing theme rule cannot ship).
- `rake css:verify_theme` — bidirectional name coverage: no unthemed
  dictionary names, no dead theme rules.
- The visual baselines — the default theme is pixel-locked; an
  intentional restyle re-records them deliberately.

## Multi-theme (the road ahead)

Upstream nests theme rules under `.style-<name>` wrappers and toggles the
wrapper class to switch themes live. poetry ships bare selectors while
exactly one theme exists; the wrapper convention (plus
`@custom-variant style-<name>`) arrives with the second official theme —
your copied theme needs no wrapper either until you want two active at
once.
