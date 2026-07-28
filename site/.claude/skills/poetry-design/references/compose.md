# compose - shape the page before building it

Write the shape down first (a sentence per region), then build. Screens
composed region-by-region from a stated shape consistently beat screens
grown element-by-element. The five mechanics below are distilled from
judged head-to-head runs - they are where composed pages win.

## Step 1 is a tool call, not a decision

Route the brief through the poetry MCP `compose` tool FIRST (no MCP:
`bin/rails g poetry:block --list` + the `poetry` skill's
`references/blocks.md`). If it returns a block, START FROM THAT SOURCE and
edit in place - do not re-derive the layout from the checklist below.
Blocks arrive with the five mechanics already composed; a blank file
arrives with none of them, and reading this checklist does not transfer
them (measured: screens built from scratch after reading it composed no
better than screens built without it).

For a whole SCREEN, prefer the `build_page` tool over `compose`: it runs
the guided workflow (probe -> plan -> direct -> snippets -> verify), so the
page architecture (section order, the states a real screen handles, the
edge cases), the theme-derived direction, and the source all arrive in
order, and it finishes on the executable `check` gate. `compose` is the
single-step router build_page calls at its snippets step; reach for it
directly for a quick route or a lone component.

## The five mechanics

1. **Containment.** Give each functional region a boundary the eye can
   find: a Card, a bordered `section`, a `bg-muted/50` band. A page of
   floating fragments reads unfinished; a page of nested-cards-in-cards
   reads like slop (the lint catches that direction). One level of
   containment, used consistently.
2. **Status color-coding.** Encode state with the status vocabulary
   (Badge `success` / `warning` / `info` / `destructive`), consistently:
   the same state always gets the same variant, and one treatment family
   per surface - solid and soft pills never mix in one table.
3. **Contextual framing.** A section that IS the page's subject keeps its
   container and breathing room (`mx-auto max-w-* p-6`); a bare component
   at the viewport origin reads cramped. Drop the wrapper only when
   composing into an already-padded frame (an app shell's content area).
4. **Page furniture.** Real screens have a header (title + description +
   primary action), section headings, and end-of-list affordances
   (pagination, a "view all" link). A component demo has none of them; a
   page needs them.
5. **Content realism.** Realistic data - names, amounts, dates, statuses in
   plausible distributions (mostly-fulfilled with a few exceptions, not
   one of each) - is part of the design. Lorem ipsum and ALL-states-once
   both read as unfinished.

## Hierarchy and density

- One primary action per view; everything else is `outline`, `ghost`, or a
  link. Two filled primary buttons side-by-side is a hierarchy bug.
- Secondary copy goes `text-muted-foreground` at `text-sm` - contrast
  carries hierarchy more cheaply than size.
- Respect the heading ladder (h1 -> h2 -> h3, no skips) - note Card titles
  default to h3; pass `title_tag:` when the card sits higher in the page.
- Space on the built-in scale, consistently: one gap rhythm per region
  (`space-y-4` / `gap-4` family), padding steps from the same scale.
- Destructive flows: tinted boundary + plain-language consequences in
  AA-clean muted copy; the alert carries icon + title only (description
  copy on the destructive tint fails AA).
- Rich navigation panels (title + description grids) want
  `poetry_navigation_menu(viewport: true)` - the morphing-card mode that
  keeps panel content contained.

## Iterate against the render

Screenshot or render what you built and look at it before calling it done
- then run the audit pass (`references/audit.md`). The linters read both
ERB source and rendered HTML; what they can't see, the critique checklist
covers.
