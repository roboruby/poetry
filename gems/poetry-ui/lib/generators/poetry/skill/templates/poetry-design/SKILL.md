---
name: poetry-design
description: >-
  The poetry taste layer: choose or adapt a theme, shape a page before
  building it, audit a finished screen, or study a brand into a DESIGN.md.
  Use when the task is about how a poetry UI should LOOK - not which
  component to call.
---

# poetry-design - the taste layer

poetry's catalog guarantees valid, accessible components; this skill covers
the decisions the catalog cannot make for you: which theme, what
macrostructure, whether the finished page reads well. It works through
tokens, variants, themes, and DESIGN.md - **never per-instance CSS** (that
reintroduces the drift the system exists to prevent).

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

## Working rules

- Deterministic first: run the linters before offering opinions - most slop
  is mechanically detectable, and every rule names its fix.
- Express every fix through a token, variant, option, theme, or DESIGN.md
  override. If a fix seems to need hand-written CSS, the real fix is a
  different composition (or an upstream gap worth reporting).
- For component contracts (options, slots, variants), load the `poetry`
  usage skill; this skill assumes you compose through it.
