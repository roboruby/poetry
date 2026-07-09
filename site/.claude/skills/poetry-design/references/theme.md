# theme - pick, adapt, or import a visual fingerprint

One visual theme per app, chosen at install: `bin/rails g poetry:install
--theme <name>` (re-runnable; the chosen fragment's bytes land in
`app/assets/tailwind/poetry/style-default.css`). Components read tokens and
`cn-*` names; the theme owns every visual decision, so switching themes is
a reinstall, not a refactor.

## The nine shipped themes

| Theme | Character |
|---|---|
| `default` | poetry's original look - the new-york-v4 lineage the library was built against |
| `vega` | closest to default: ring-based surfaces, subtle blur scrims, xl radii |
| `nova` | compact - tighter paddings and smaller surfaces |
| `mira` | compact and quiet - relaxed xs body text, heavily dimmed drawer scrims |
| `rhea` | soft and elevated - capped 4xl radii, shadow-xl, blurred scrims |
| `maia` | fully rounded - 4xl surfaces, deeply dimmed scrims |
| `luma` | soft-round - blurred scrims and a floating drawer frame |
| `lyra` | boxy and sharp - radius zero, type one step down, made for mono fonts |
| `sera` | editorial - uppercase tracked type, underline-only fields, serif pairing |

Choosing by brief, not by taste-in-a-vacuum:

- Dense operational tools (admin, monitoring, tables everywhere): `nova` or
  `mira` - the compact surfaces buy rows.
- Consumer/marketing warmth: `rhea`, `maia`, or `luma` - rounded, elevated,
  soft scrims.
- Technical/developer products: `lyra` - sharp, mono-biased, zero radius.
- Editorial/content products: `sera` - tracked uppercase labels, serif
  pairing, underline fields.
- `default` is the stock look. Picking it is legitimate but should be a
  DECISION - when a brief implies any character at all, a non-default theme
  is usually the stronger answer (the design-lint `stock-theme-nudge` rule
  exists for exactly this).

## Fonts ride the theme as metadata

No poetry theme moves a font token - `lyra` is biased hard to mono
(JetBrains Mono; radius forced to zero) and `sera` keeps serif company
(Noto Serif, Instrument Serif), but both express their typography through
size, weight, tracking, and uppercase utilities. The font-family itself is
the app's call: add the family in the app's own CSS/font pipeline when
installing lyra or sera.

## Status color vocabulary

The token set carries `--success`, `--warning`, and `--info` alongside
`--destructive` (all four AA-managed in both modes). Badges ship soft
status variants on them. Use the set; never invent status colors from
palette utilities.

## The DESIGN.md door (brand import/export)

- `bin/rails poetry:design:export` writes this app's DESIGN.md (tokens +
  treatment; `POETRY_DESIGN_PATH` to target elsewhere, `POETRY_DESIGN_FORCE=1`
  to overwrite a non-poetry file). Run it so external design skills can read
  the app's current design.
- `bin/rails "poetry:design:import[path/to/DESIGN.md]"` plans role-mapped
  token overrides from a foreign DESIGN.md (a brand study, a Stitch export,
  a brand study): conservative role aliases, WCAG AA enforced on the
  MERGED set, failing pairs dropped with a deterministic nearest-AA
  suggestion, dark values pinned when the source is light-only. The report
  lists every mapping and every drop (`POETRY_DESIGN_JSON=1` for JSON);
  `POETRY_DESIGN_FORCE=1` is the only way a failing pair ships.
- Overrides land in `app/assets/tailwind/poetry/design-overrides.css` - the
  one sanctioned place brand values live outside the theme fragment.

Adapting a theme = shipped theme + DESIGN.md overrides on top. Full brand
work = `study` (see `references/study.md`) then import.
