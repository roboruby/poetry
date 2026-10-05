# Documentation standard

poetry components carry two kinds of documentation, and they have
different readers. YARD comments serve the person or agent reading the
source; projected strings (part descriptions, agent rules, option
metadata) are published verbatim through the registry, the agent
surface, and the docs. Write each for its consumer.

## The class docblock

Every published component class opens with a YARD docblock:

- **One to three sentences** on what it renders and when to reach for
  it. Present tense, no history. This is the *reference lead* - a public
  reader with zero codebase context must parse every word.
- Optionally ONE short paragraph of load-bearing behavior facts a USER
  needs (keyboard behavior, required slots, form participation), written
  to stand alone. Maintainer rationale is a different register: it lives
  as a plain comment above the method it concerns, never in the class
  docblock. Whole docblock ≤ 15 lines.
- **One `@example`** showing minimal usage through the helper or
  `render`. Add a second example only when the primary axis (variant,
  size, slots) isn't obvious from the first.
- Internal component classes (`internal_component!`) get a one-line
  comment and `@api private` instead.

```ruby
# Renders a dismissible inline notice with an optional action slot.
# Variants map to semantic intent, so themes restyle it wholesale.
#
# @example
#   render MyApp::Callout::Component.new(variant: :success) { "Saved." }
class Component < Poetry::Core::Component
```

## Public methods

- YARD tags (`@param`, `@return`, `@example`) on every public method
  whose signature or return isn't obvious from the name.
- Template-facing methods (`*_attributes`, `*_id`, `*_classes`, part
  builders) and lifecycle overrides (`initialize`, `before_render`,
  `call`) carry a one-line comment ending in `@api private` - they are
  public for the template's sake, not the consumer's, and the doc set
  hides them.
- Hand-written slot writers a caller uses (`with_*`) are real public
  API: full docs, never `@api private`.
- Markdown markup; full sentences; wrap at the file's prevailing width.

## Declaration docs

Every `option` and `style` carries a `doc:` string, and every
`renders_one`/`renders_many` carries one too - with `renders:` passing
the slot's lambda as a keyword so the doc reads first. (`slot_doc` is
the fallback for a doc declared away from its declaration, e.g. in a
different module.) That string is the declared surface's documentation everywhere at
once - the registry (option/style/slot descriptions), llms.txt and the
agent surface, the component page's API section, and the generated API
reference - with the machine facts (type, default, variants)
auto-appended, so the prose adds MEANING only:

- One sentence, two at most: the caller-visible effect and its
  interactions ("Ignored unless `tag: :a`."), never the implementation
  ("sets @foo").
- Never repeat the type, default, or variant list - the projections
  carry those already.

```ruby
option :loading, :boolean, default: false,
       doc: "The no-JS loading state: aria-busy, a spinner, and the control disabled."

renders_one :leading, doc: "Optional leading visual, rendered inside the icon span."

renders_one :trigger,
            doc: "The button that opens the dialog.",
            renders: lambda { |**options, &block| ... }
```

Constants that define the surface get one-liners too: vocabulary arrays
("The closed vocabulary for the variant axis."), `AGENT_RULES`
("Projected into the registry, llms.txt, and the agent surface.").

## Private methods

Plain comments, and only where the *why* isn't visible in the code. A
private method whose name states its job needs no comment.

## Projected strings

Part descriptions, agent rules, option and slot descriptions, and
`requires_content` hints are machine-published documentation:

- Write for the consumer who has never seen the source: name the DOM
  reality ("the rendered control itself"), the condition ("loading: is
  set"), the rule ("icon-only buttons MUST pass label:").
- No abbreviations that only make sense inside this codebase.
- Agent rules are imperatives: what to do, what never to do, one rule
  per entry.

## What comments never contain

Comments explain the component to its next reader. Reasoning stands on
its own - state the constraint, not where it came from:

- **No internal references**: planning documents, decision indexes,
  milestone names, issue numbers, links into private notes. If the
  reasoning matters, write the reasoning; the citation is noise to
  every reader who isn't the author.
- **No other libraries**: naming another library belongs in
  `THIRD_PARTY_NOTICES.md` when code was adapted, and nowhere
  otherwise. "The base-contract rule: an icon-only control without an
  accessible name never ships" carries the rule; attribution lives in
  the notices file.
- **No narration**: nothing that restates what the next line does, and
  nothing addressed to a reviewer ("this is correct because..."). A
  comment earns its place by stating a constraint the code can't show.

## YARD setup

Each gem carries a `.yardopts` (markdown markup, README as the index,
`--hide-api private`, previews and generator templates excluded,
CHANGELOG and notices as extra files) and loads the shared handler kit
(`poetry-core/yard/poetry_yard.rb`), which makes the declarative
surfaces - `class_methods do`, `option`/`style` readers, slot writers,
`part` anatomy - visible to the doc build.

Gates, from the gem root:

- `rake yard:verify` - fails on any warning (an unresolvable reference
  or malformed tag is a review finding; structural warnings are
  allowlisted in the task).
- `rake yard:coverage` - the ratchet: fails when the undocumented-object
  count exceeds the committed `.yard_coverage` floor. After a
  documentation pass, lower the floor with `rake yard:coverage:record`.

Previews are OUTSIDE the doc set: preview.rb comments are for gallery
authors (Lookbook tags like `@label`/`@!group` live there) and are never
published.
