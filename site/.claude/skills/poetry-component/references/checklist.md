# Component audit checklist

Run this against one component file at a time, top to bottom - the
checks are ordered so violations surface in file order. The audit has
two passes: structure, then documentation. It never changes behavior:
rendered output, projected surfaces, and test results are identical
before and after an audit fix, except where a projected string was
itself the finding.

## Pass 1 - structure

- [ ] `# frozen_string_literal: true` heads the file.
- [ ] Sections present appear in canonical order: includes & class
      config → constants → slots → stimulus → styles & options →
      validations → parts → lifecycle → public methods → private
      methods → nested classes. (Absent sections are skipped, not
      stubbed.)
- [ ] Constants: vocabularies before the agent contract
      (`AGENT_RULES`, `REQUIRES_ANY`, `SLOT_RENDERS`); every constant
      above the first DSL call that reads it; all `.freeze`d.
- [ ] No declaration was reordered *within* its section - option,
      part, and slot order projects in declaration order. Verify with
      the diff, not by eye.
- [ ] Lifecycle methods (`initialize`, `before_render`, `call`) lead
      the public methods, in that order.
- [ ] Exactly one `private` keyword; nothing public below it.
- [ ] Inner machinery classes declare `internal_component!`.
- [ ] Nested classes sit last in the class body, above the `private`
      divider (constants are never private-scoped).

## Pass 2 - documentation

- [ ] Class docblock: purpose in 1-3 sentences + at least one
      `@example` (published components); `@api private` one-liner
      (internal components).
- [ ] Public methods with non-obvious signatures carry `@param` /
      `@return`; examples where usage isn't clear from the signature.
- [ ] Projected strings (part descriptions, agent rules, option
      descriptions, `requires_content` hints) read consumer-facing:
      concrete DOM reality, explicit conditions, imperative rules.
- [ ] No internal references anywhere in comments: no planning-doc or
      decision-index citations, no milestone names, no links to
      private notes. Reasoning is stated inline or removed.
- [ ] No other library named in any comment or string (notices file
      excepted).
- [ ] No narration comments (restating the next line) and no
      reviewer-addressed comments.
- [ ] Comment prose is complete sentences; abbreviations only if a
      newcomer reads them cold.

## Verification

- [ ] Full suite green.
- [ ] `git diff` shows only: comment changes, section moves, doc
      strings intentionally rewritten. No logic lines changed.
- [ ] If a projected string changed: the registry / agent-surface /
      check tests that assert on it were updated in the same change,
      and the new text is an improvement for the consumer, not a
      paraphrase.
- [ ] `yard doc` (or the gem's docs build) runs warning-clean on the
      touched files.

## Recording findings that are out of scope

Anything discovered that is *not* structure or documentation - a bug, a
missing validation, a contract gap - does not get fixed in an audit
pass. Record it separately and keep the audit diff clean.
