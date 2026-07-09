# study - extract a brand into a DESIGN.md poetry can import

`study` turns a brand surface (a URL, screenshots, an existing style guide)
into the design-skill ecosystem's shared artifact: a DESIGN.md. poetry both
writes and reads the format, so the loop is:

    study the brand -> DESIGN.md -> bin/rails "poetry:design:import[DESIGN.md]"

## Writing the DESIGN.md

Front-matter carries the machine-readable part:

- Flat `colors:` = the LIGHT mode palette, role-named (`brand`, `surface`,
  `text`, `accent`, ...). poetry's importer maps roles conservatively
  (`brand` -> `--primary`, `surface` -> `--card`, `text` -> `--foreground`,
  Material-style `on-*` -> `*-foreground`) and reports every mapping.
- `modes.dark:` for dark values when the brand defines them. A light-only
  study is fine: poetry PINS dark to its shipped defaults rather than
  letting light values bleed into dark mode.
- `rounded:` resolved to px; typography as metadata (family names, pairing
  intent) - fonts never enter CSS via import.
- Markdown sections (voice, imagery, spacing notes) carry the prose the
  front-matter can't; the importer ignores what it can't parse and REPORTS
  it rather than guessing.

**Extract, never fabricate.** Record only what the brand actually shows.
If the brand has no dark mode, don't invent one; if you can't find a
motion language, omit the section. Dropped-with-a-note beats guessed - the
import report is the honest ledger.

## What import will do with it

Role-mapped token overrides, WCAG AA enforced on the merged set: failing
pairs are DROPPED with a deterministic nearest-AA suggestion (an OKLCH
lightness walk, chroma held), and `POETRY_DESIGN_FORCE=1` is the only way
a failing pair ships. Expect the report to move some values - a brand hex
that fails AA against white comes back as the nearest passing neighbor,
which is usually what the brand's own accessible surfaces do anyway.

## redesign - same content, different fingerprint

`redesign` keeps copy, information architecture, and brand meaning, and
swaps the visual fingerprint: pick a different shipped theme
(`references/theme.md`), re-run the brand's DESIGN.md on top if one
exists, and re-audit. Nothing in the templates should need to change - if
a redesign forces template edits, the original leaned on per-instance
styling it shouldn't have had.
