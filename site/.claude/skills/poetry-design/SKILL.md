---
name: poetry-design
description: >-
  Design guidance for building poetry UIs: theme selection, page
  composition (macrostructure, hierarchy, containment, status color),
  the visual audit of a finished screen, and studying a brand into a
  DESIGN.md. Load this WHENEVER building, composing, or restyling a
  page, screen, dashboard, or view with poetry - alongside the poetry
  usage skill, before composing - not only when the task mentions
  design.
---

# poetry-design - the taste layer

poetry's catalog guarantees valid, accessible components; this skill covers
the decisions the catalog cannot make for you: which theme, what
macrostructure, whether the finished page reads well. Any task that builds
a PAGE is a design task - load this before composing, not after something
looks wrong. It works through tokens, variants, themes, and DESIGN.md -
**never per-instance CSS** (that reintroduces the drift the system exists
to prevent).

## Verbs

- **theme** (`references/theme.md`) - pick or adapt one of the nine shipped
  themes; wire a brand in through the DESIGN.md import door.
- **compose** (`references/compose.md`) - shape a page BEFORE building it:
  macrostructure, hierarchy, framing, content realism. The checklist here
  is distilled from judged head-to-head runs.
- **audit** (`references/audit.md`) - review a finished screen: run the
  deterministic design-lint tier first, then the critique checklist for
  what detectors cannot see.
- **study** (`references/study.md`) - extract a brand's design DNA into a
  DESIGN.md poetry can import; `redesign` = keep the content, swap the
  fingerprint.
- **figma** (`references/figma.md`) - bring a Figma design into poetry:
  import its variables as an AA-gated theme, or translate a selection into
  components across the Figma + poetry MCPs.
- **paper** (`references/paper.md`) - bring a paper.design canvas into
  poetry: import its theme, or translate the canvas across the Paper +
  poetry MCPs.

## Working rules

- Deterministic first: run the linters before offering opinions - most slop
  is mechanically detectable, and every rule names its fix.
- Express every fix through a token, variant, option, theme, or DESIGN.md
  override. If a fix seems to need hand-written CSS, the real fix is a
  different composition (or an upstream gap worth reporting). The one
  sanctioned exception: a DECLARED `cn-*` override - host CSS restyling a
  theme-owned class, recorded with a reason under `overrides:` in
  config/poetry_components.yml after the user confirms intent
  (`bin/rails poetry:design:overrides` reports drift). Never declare an
  override to skip a fix.
- For component contracts (options, slots, variants), load the `poetry`
  usage skill; this skill assumes you compose through it.
