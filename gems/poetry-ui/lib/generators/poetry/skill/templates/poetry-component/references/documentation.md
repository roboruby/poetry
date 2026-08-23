# Documentation standard

poetry components carry two kinds of documentation, and they have
different readers. YARD comments serve the person or agent reading the
source; projected strings (part descriptions, agent rules, option
metadata) are published verbatim through the registry, the agent
surface, and the docs. Write each for its consumer.

## The class docblock

Every published component class opens with a YARD docblock:

- **One to three sentences** on what it renders and when to reach for
  it. Present tense, no history.
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
- Lifecycle methods (`initialize`, `before_render`, `call`) get a
  comment only when they do something beyond the base class contract.
- Markdown markup; full sentences; wrap at the file's prevailing width.

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
CHANGELOG and notices as extra files). `yard doc` from the gem root
builds the API docs; keep it warning-clean - an unresolvable reference
or malformed tag is a review finding.
