# paper - bring a paper.design canvas into poetry

Paper's canvas is real HTML + CSS, and its tokens are CSS custom properties
on the same axes poetry themes use, so it speaks poetry's dialect directly.
Two doors, independent - a theme handoff, and a canvas-to-components handoff.
Translate INTO poetry primitives and tokens; never transcribe raw styles.

## Door 1: theme -> an AA-gated theme (no MCP needed)

1. In Paper, run **Copy theme** and paste the CSS into a file (e.g.
   `paper-theme.css`).
2. Run `bin/rails poetry:paper:import[paper-theme.css]` (or
   `poetry:design:import` - it detects `.css`).
3. **Read the report.** The importer parses the `:root` / `@theme` custom
   properties (stripping a Tailwind `color-` namespace), resolves `var()`
   references, converts values into poetry's OKLCH model, then measures every
   touched pair against WCAG AA. A value that fails AA is **dropped and
   reported with the nearest passing suggestion** - never shipped; a property
   with no poetry role is dropped and listed, never guessed.
4. It writes `app/assets/tailwind/poetry/design-overrides.css` and wires the
   import. Rebuild CSS. `POETRY_DESIGN_FORCE=1` / `POETRY_DESIGN_JSON=1` as
   with any import.

Copy theme is a one-shot copy, not a live sync - re-run the import when the
Paper theme changes.

## Door 2: a canvas -> components (dual-MCP)

Needs the **Paper MCP** connected alongside the poetry MCP. Paper's MCP ships
with the Paper Desktop app and runs locally once a file is open; register it
once: `claude mcp add paper --transport http http://127.0.0.1:29979/mcp
--scope user`. The free tier's 100 tool calls/week is enough for a handoff.

Flow:

1. Read the design - `get_selection` / `get_tree_summary` for structure,
   `get_jsx` (ask for the Tailwind form) and `get_computed_styles` for the
   styling, `get_screenshot` to keep layout fidelity.
2. Land the tokens first via Door 1 so Paper's variables line up with poetry
   theme tokens.
3. Translate, do not copy. Map each Paper subtree to the nearest poetry
   primitive - consult `list_components` / `describe_component`; assemble with
   `compose` / `build_page`, never hand-authored markup.
4. Run poetry `check` LAST - a PASS verdict, not an eyeball.

Mapping guide:

- Artboard -> a poetry block or page.
- Node subtree -> the nearest poetry component.
- Tailwind classes from `get_jsx` -> poetry variants and theme tokens, not
  copied class strings.
- Computed styles -> poetry theme tokens (Door 1), never per-instance CSS.

Optional round-trip: push a rendered poetry component back into Paper as
editable layers with `write_html`, so a designer can review poetry's output
on the canvas. Bank this as a review loop, not a build step.
