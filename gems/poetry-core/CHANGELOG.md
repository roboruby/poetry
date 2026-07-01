## [Unreleased]

- M2: `class_variants` absorbed in-tree as `CSS::Resolver` — the
  base / element / variant / compound dictionary DSL on `Style`, with **no
  defaults storage** (defaults live only on the component's
  `style :attr, default:` — the single source of truth) and a bounded FIFO
  cache on the shared `CSS::Merger` (tailwind_merge runs once per distinct
  combo). One fewer runtime dependency.
- M2: the BEM token IR (`Styles#bem`, block from `component_path`) +
  `config.css_mode =:tailwind |:bem` — `:bem` emits the stable
  class contract for bring-your-own-CSS hosts; `CSS::BemReference`
  generates the documented reference stylesheet, capsule-digest-stamped
  (the capsule-digest leak guard).
- M2: the class Verifier (`CSS::Verifier`) — validates every
  dictionary class against a compiled Tailwind stylesheet, with
  did-you-mean suggestions for hallucinated classes; `CSS::Safelist` +
  `CSS::TemplateClasses` (Herb-AST static-class extraction + the herb
  parse gate). Rake: `css:safelist`, `css:verify[compiled.css]`,
  `css:bem_reference`, `css:herb`.
- M1: canonical DTCG design tokens (`tokens/tokens.dtcg.json`) — OKLCH semantic
  roles, shadcn/ui v4 drop-in var set, light + dark (`.dark` class convention).
- M1: token generators (`rake tokens:generate`) emitting `tokens/tokens.css`,
  `tokens/tailwind-theme.css` (Tailwind v4 `@theme inline`), and the DESIGN.md
  front matter (prose body preserved); `rake tokens:verify` drift gate wired
  into the default task.
- M1: the AAA-contrast CI gate (`Poetry::Core::Tokens::ContrastGate`) — every
  semantic text pair asserted in both modes against a locked ledger (WCAG 2.2
  AA floor, AAA where achievable, explicit AA exceptions). Dark destructive is
  gated as rendered (`bg-destructive/60` composited over the background).
- Parity delta vs shadcn neutral: light `muted-foreground` darkened to
  `oklch(0.545 0 0)` (shadcn's `0.556` measures 4.34:1 on `muted` — sub-AA).

## [0.0.1] - 2026-06-27

- Initial extraction of the poetry-core framework layer.
