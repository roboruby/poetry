---
name: poetry-component
description: >-
  Author and audit poetry components: the canonical class anatomy
  (section order every component follows), the documentation standard
  (YARD + projected strings), and the audit checklist. Load this
  WHENEVER creating a new component that inherits from
  Poetry::Core::Component, extending an existing component family, or
  reviewing a component file for structure and documentation - the
  anatomy is the contract that keeps every component readable the same
  way.
---

# poetry-component - the authoring layer

poetry's catalog guarantees valid, accessible components; this skill
covers building one of your own. A component that follows the canonical
anatomy is legible to every reader - human, agent, and the machine
surfaces (registry, contract checks, docs) that project from its
declarations. Load this before writing the class, not after it fails
review.

## Verbs

- **create** (`references/anatomy.md`) - author a new component: the
  section order, what each DSL declares, and a complete skeleton to
  start from.
- **document** (`references/documentation.md`) - the documentation
  standard: the class docblock, YARD on public methods, and how to write
  the projected strings (part descriptions, agent rules) that machines
  consume verbatim.
- **audit** (`references/checklist.md`) - review an existing component
  against the anatomy and the documentation standard; the checklist is
  ordered so violations surface in file order.

## The one rule that spans all three

Declaration order inside a section is meaningful: options, parts, and
slots project into the registry and the agent surface in declaration
order. Move whole sections to match the anatomy; never reorder
declarations within a section unless you intend to change the projected
surface.

## Boundaries

- A new component inherits from `Poetry::Core::Component` (or a
  published family's base) and lives in its own `app/components`
  namespace. Never copy a poetry component's source into the app to
  modify it - subclass it, or compose it in a template.
- Inner classes that exist only to serve a family (item builders,
  internal wrappers) declare `internal_component!` so the registry and
  every surface derived from it skip them.
- Behavior belongs to Stimulus controllers declared through
  `use_stimulus`; a component never ships inline `<script>`.
