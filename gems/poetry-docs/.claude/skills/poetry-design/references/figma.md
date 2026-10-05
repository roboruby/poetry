# figma - bring a Figma design into poetry

Two doors, independent. Take the first for a palette/theme handoff; the
second when a whole frame must become working components. Both translate
INTO poetry primitives and tokens - never transcribe Figma's absolute
positions, raw hex, or pixel gaps into markup.

## Door 1: variables -> an AA-gated theme (no paywall, no MCP)

Figma variables become poetry token overrides through the same importer a
DESIGN.md uses, so imported swatches inherit poetry's contrast law.

1. In Figma, export the variables as JSON with a free plugin - **Tokens
   Studio** or **Design Tokens** (six7). These use the Plugin API, which
   reads variables on every plan; the REST Variables API is Enterprise-only,
   so do not rely on it.
2. Run `bin/rails poetry:figma:import[variables.json]` (or
   `poetry:design:import` - it detects `.json`).
3. **Read the report.** The importer walks DTCG groups and modes, resolves
   `{aliases}`, flattens `primary/DEFAULT` and `primary/foreground`, converts
   hex / rgb / DTCG-object / oklch into poetry's OKLCH model, then measures
   every touched pair against WCAG AA. A swatch that fails AA is **dropped
   and reported with the nearest passing value** - never shipped. Anything
   with no poetry role is dropped and listed too; the importer never guesses.
4. It writes `app/assets/tailwind/poetry/design-overrides.css` and wires the
   import. Rebuild CSS. `POETRY_DESIGN_FORCE=1` ships failing pairs on
   purpose (rarely right); `POETRY_DESIGN_JSON=1` prints a machine report.

Names that do not match a poetry role (`color/brand/600`, say) are dropped,
not invented. Rename in Figma toward poetry's semantic roles (`background`,
`foreground`, `primary`, `muted-foreground`, `border`, ...) and re-run.

## Door 2: a selection -> components (dual-MCP)

Needs the **Figma MCP** connected alongside the poetry MCP in one agent. The
remote server (`https://mcp.figma.com/mcp`) reads files by node id on all
plans; the live current-selection path (`get_variable_defs` in context)
wants the desktop app plus a Dev or Full seat. The server is in beta.

Flow:

1. Read the design - `get_design_context` (React + Tailwind by default),
   `get_variable_defs` (the tokens a selection uses), `get_screenshot` (keep
   layout fidelity).
2. Land the tokens first via Door 1 so Figma's variables line up with poetry
   theme tokens; reconcile, do not duplicate.
3. Translate, do not copy. Map each Figma node to the nearest poetry
   primitive - consult `list_components` / `describe_component`; assemble
   with `compose` / `build_page`, never hand-authored markup.
4. Run poetry `check` LAST - a PASS verdict, not an eyeball.

Mapping guide:

- Auto-layout frame -> a poetry block or a page section (`compose` routes it).
- Component instance -> the nearest poetry component; its variant property ->
  the poetry `variant` option, not a new class.
- Text -> component content / slots.
- Color, spacing, radius tokens -> poetry theme tokens (Door 1), never
  per-instance CSS.

Optional: the Figma `create_design_system_rules` prompt writes a rule file
that teaches Figma's codegen agent poetry's conventions - point it here so
token names and helper calls come out right.

Code Connect (Dev Mode showing `poetry_button(...)` ERB) is possible through
`*.figma.ts` template files, but it needs an Org/Enterprise plan, a Dev/Full
seat, and a Figma UI kit poetry does not ship yet. Treat it as a later,
enterprise-tier path, not a prerequisite.
