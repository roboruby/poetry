---
name: poetry
description: >-
  Build Rails views with the poetry component library: helper
  contracts, options, slots, blocks, and the check workflow. Use
  whenever writing or editing ERB/UI in an app that has poetry
  installed.
---

# poetry - component usage

Generated from the poetry registry (65 components + 13 chart components + 6 blocks). After updating
poetry gems, regenerate with `bin/rails g poetry:skill`.

## Guardrails

- FIRST MOVE, for every brief: call the poetry MCP `compose` tool
  with the task text, before writing any ERB. It routes you to the
  matching vetted block (source included, adapt in place - the
  known winning path for screens) or to the right components for
  single-component work. No MCP? Open `references/blocks.md` and
  `bin/rails g poetry:block --list`. Composing a screen from
  scratch when a block matched is the known losing path.
- Compose with the `poetry_<name>` helpers; never hand-write `cn-*`
  classes, raw hex/oklch colors, or off-scale arbitrary values -
  tokens and variants carry the design.
- Options are keywords; content is the block. Helpers take at most
  the positional arguments their contract lists - most take none.
- A typed slot renders another component: the call takes THAT
  component's props, never a render block.
- Icon names are kebab-case symbols: `:"circle-check"`, never
  `:circle_check`.
- Status reads as a set: one badge treatment family per surface -
  never mix solid (default/destructive) and soft
  (success/warning/info) pills in one table.
- Page framing: a section that IS the page's subject keeps its
  container and breathing room (`mx-auto max-w-* p-6`); a bare
  component at the viewport origin reads cramped. Drop the wrapper
  when composing into an already-padded frame.
- One visual theme per app (chosen at install); components read
  tokens, never restate them.
- Check comes LAST: run `bin/rails poetry:check` (or the poetry MCP
  `check` tool - instant, no app boot) as the FINAL action, after
  your last edit. An edit made after your last check is unverified
  markup - re-run check before finishing, every time.

## Find your component

Load the reference for the family you are composing in - each file
carries the full contracts (options, variants, slots, wiring, RULE
lines) for its components:

- **forms** (`references/forms.md`): button, button_group, calendar, checkbox, combobox, date_picker, field, input, input_group, input_otp, label, native_select, radio_group, select, slider, switch, textarea, toggle, toggle_group
- **overlays** (`references/overlays.md`): alert_dialog, command, command_dialog, context_menu, dialog, drawer, dropdown_menu, hover_card, menubar, popover, sheet, tooltip
- **data** (`references/data.md`): accordion, avatar, badge, card, carousel, collapsible, data_table, empty, item, table
- **feedback** (`references/feedback.md`): alert, deferred, progress, skeleton, spinner, toast, toaster
- **navigation** (`references/navigation.md`): breadcrumb, navigation_menu, pagination, sidebar, tabs
- **foundations** (`references/foundations.md`): icon, kbd, link, marker, separator
- **chat** (`references/chat.md`): attachment, bubble, message, message_scroller
- **layout** (`references/layout.md`): aspect_ratio, resizable, scroll_area
- **blocks** (`references/blocks.md`): app-shell, data-index, destructive-panel, page-header, section-card, top-nav
- **charts** (`references/charts.md`): adapter_chart, area_chart, bar_chart, composed_chart, container, legend_content, line_chart, pie_chart, radar_chart, radial_bar_chart, scatter_chart, tooltip_content, tooltip_layer

## Composing a page? Load poetry-design

Building or restyling a full page, screen, or dashboard - not a
lone component? Load the `poetry-design` skill BEFORE composing:
theme fit, page macrostructure, hierarchy, status color, and the
finishing audit live there. Component contracts alone do not make
a composed page - and neither does guidance: start the page from
`compose`'s block match and adapt, don't rebuild its advice from
a blank file.
