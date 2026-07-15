# audit - review a finished screen

Deterministic first, judgment second. Most AI-UI slop is mechanically
detectable; run the machines before offering opinions. And the machines
also run LAST: any edit the audit produces re-opens the gate - finish
with a clean `poetry:check` run AFTER the final edit, never before it.

## Run the linters

- `bin/rails poetry:check` - the hard gate: unknown components, options,
  variants, icon names, arity, wiring. Errors block; fix them first.
- `POETRY_CHECK_DESIGN=1 bin/rails poetry:check` - adds the design-slop
  tier (warnings; the taste tier). `POETRY_CHECK_JSON=1` for machine
  output; both accept a glob argument for one file.
- `bin/rails poetry:verify` - classes vs the compiled CSS (catches classes
  that never compiled, i.e. styles silently not applying).

## The design-lint rules (what each catches)

Every finding names its fix in the message. The thirteen rules:

- `card-in-card` - a Card nested in a Card; flatten to one containment level.
- `icon-tile-over-heading` - the decorative icon-in-a-tile stacked above
  every heading; the stock AI-UI tell.
- `wall-of-cards` - everything boxed identically; vary the surface or merge
  regions.
- `off-scale-arbitrary` - `w-[347px]`-style values that sit off the scale;
  use the scale spelling.
- `gradient-off-token` - gradients built from palette utilities instead of
  tokens.
- `heading-skip` - h1 -> h3 ladder skips (remember Card titles default h3;
  pass `title_tag:`).
- `mixed-status-weight` - solid and soft status pills mixed in one table;
  keep one treatment family per surface.
- `center-everything` - body copy and controls center-aligned page-wide;
  center is for empty states and heroes.
- `shadow-stack` - stacked/oversized shadows on nested surfaces.
- `type-scale-monotony` - all content text at one size; hierarchy needs a
  scale (DOM tier - reads computed styles).
- `adjacent-same-surface` - sibling regions with identical surfaces and no
  separation (DOM tier).
- `contrast-adjacent` - adjacent text failing contrast against its own
  surface (DOM tier).
- `stock-theme-nudge` - the app still wears the stock look while a foreign
  DESIGN.md is present (DOM tier).

## Score it (deterministic)

When the audit needs a NUMBER - a PR gate, a before/after, a fleet
sweep - compute the adherence score from findings, never from a
subjective sense of overall quality (the spectrum-audit rule).

Severity weights, fixed:

- **Critical 10** - each `poetry:check` ERROR (unknown component/option/
  variant/icon, arity, wiring, slot misuse). These also block outright.
- **High 5** - each `poetry:verify` failure (a class that never
  compiled: styling silently not applying).
- **Medium 2** - each design-slop WARNING (`POETRY_CHECK_DESIGN=1`, the
  thirteen rules above).
- **Low 1** - each critique-checklist finding (the judgment items; name
  the surface for every one you count).

Per category: `score = 100 - min(100, sum_of_weights)`. Overall
adherence = the weighted mean: contracts 40%, compiled styling 25%,
design slop 25%, critique 10%. Report all four category scores plus the
overall, each with its finding count - a score with no finding list is
not a score.

## The critique checklist (what detectors cannot see)

Work the rendered page, not the source:

1. **Squint test** - blur your eyes (or shrink the screenshot): does the
   page still have a shape - regions, a focal point, a reading order? If
   it goes uniform gray, hierarchy is missing.
2. **One-decision test** - can you say in one sentence what this page most
   wants the user to do? Is that the one filled-primary element?
3. **Consistency sweep** - same state, same treatment; same gap rhythm per
   region; aligned edges (one container width, not three).
4. **Content honesty** - would a real user's data look like this? Plausible
   distributions, realistic names/dates/amounts, an empty state where the
   data could be empty.
5. **Framing** - does the page's subject have breathing room? Does anything
   sit naked at the viewport origin?

Report findings in the linters' voice: name the surface, name the fix, and
express every fix through a token, variant, option, theme, or DESIGN.md
override - never per-instance CSS.
