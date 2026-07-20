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

poetry ships more than one theme (`themes/*.css` in each gem — `default`
is new-york-v4; `vega`, `nova`, `mira` and `rhea` are upstream style
ports: vega the clean neutral pilot, then the density trio — nova
reduced, mira compact, rhea soft-round compact). Pick one at install
time:

```sh
rails g poetry:install --theme vega          # or --charts --theme mira
```

The chosen fragment fills the **same slot** (`poetry/style-default.css` —
the slot filename never changes), so switching themes later is a plain
re-run with a different `--theme`: the slot is overwritten in place and
no entry lines accrete. `style-default.css` is vendored — every re-run
refreshes it, so upstream visual updates keep flowing.

To own the design outright instead:

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
  exist in the compiled build (a missing theme rule cannot ship). With no
  `POETRY_THEME` set it compiles **every** shipped theme, so an incomplete
  fragment can never sit green; set `POETRY_THEME=<name>` to gate one.
- `rake css:verify_theme` — bidirectional name coverage per fragment: no
  unthemed dictionary names, no dead theme rules.
- The visual baselines — the default theme is pixel-locked per commit;
  each shipped theme keeps its own golden set
  (`test/visual_baselines/<theme>/`, recorded with
  `POETRY_THEME=<name> VISUAL_REBASELINE=1`) and the full theme matrix
  runs at milestone closes rather than per commit.

## Color scheme (dark mode)

Every theme ships both modes: the tokens define `:root` (light) and
`.dark` overrides, and both blocks carry `color-scheme`, so UA
scrollbars, form-control chrome and canvas defaults follow the app's
mode rather than the OS preference. What the gem does not decide
is WHEN `.dark` applies — that part is one line in the host layout:

```erb
<head>
  <%= poetry_color_scheme_script %>
  <%# ...stylesheet/javascript tags... %>
</head>
```

Render it inside `<head>`, before the stylesheets. Before first paint it
reads the stored preference (`localStorage["poetry-color-scheme"]`),
falls back to `prefers-color-scheme`, and toggles `.dark` on `<html>` —
no light-mode flash on refresh (the pothole every hand-rolled dark mode
hits once), and an unset preference follows the OS live, including
mid-session OS switches. Because the class lives on `<html>`, Turbo
visits and bfcache restores keep the mode with no re-application.

The script also installs the switch API — wire any control to it:

```erb
<%= poetry_button(variant: :ghost, size: :icon, label: "Toggle dark mode",
                 onclick: "Poetry.colorScheme.toggle()") do %>
  <%= poetry_icon(name: :"sun-moon") %>
<% end %>
```

`Poetry.colorScheme.current()` reads the active mode, `set("dark")` /
`set("light")` pins one, `toggle()` flips, and `clear()` returns to
following the OS. Every change dispatches `poetry:color-scheme` on
`document.documentElement` (bubbling, `detail: { mode }`) for anything
that must redraw with the mode — chart recoloring, embedded editors,
maps.

## Multi-theme (what ships, what's ahead)

Shipped today: **install-time selection** — one theme per build via
`--theme`, no wrapper needed, which is why poetry fragments use bare
selectors. Upstream instead compiles all of its styles into one sheet,
nests each under a `.style-<name>` wrapper and toggles the wrapper class
on `<body>` to switch live; that convention (plus
`@custom-variant style-<name>`) arrives when poetry needs two themes
active at once — realistically the docs-site theme switcher. Your copied
theme needs no wrapper either until then.

Porting notes per fragment (translation disciplines, what stayed
poetry-idiom, what was dropped and why) live in
`docs/<theme>-port-ledger.txt` and each fragment's header comment. The
port pipeline itself (detector, per-theme plans, writer, thin-body scan)
is banked in `script/theme_port/`.
