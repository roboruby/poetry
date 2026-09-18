# Changelog

## [0.1.5] - 2026-09-18

### Changed

- 43 methods the reference already hid with `@api private` are Ruby-private now: each was called only by its own class or template, so the runtime enforces what the tag only stated. A host that reached one gets a NoMethodError instead of an internal that may change without notice. The tag remains on the internals the family shares between its gems and on whole internal classes.
- Every class, module and method carries a one-sentence description, private helpers included: `rake yard:coverage:all` measures the whole tree (a tag-only docstring counts as blank) and the committed floor now stands at zero.
- The palette builder reads its sources, chooses its roles, builds the chart series and writes the hash in separate steps; the oracle parity suite holds every output byte for byte, and two tests pin that a primary already on the right side of its canvas is left alone in the derived mode.

## [0.1.4] - 2026-09-15

Lockstep release with the family; no changes in this gem.

## [0.1.3] - 2026-09-13

Lockstep release with the family; no changes in this gem.

## [0.1.2] - 2026-09-13

Lockstep release with the family; no changes in this gem.

## [0.1.1] - 2026-09-08

Lockstep release with the family; no changes in this gem.

## [0.1.0] - 2026-09-05

Initial public release. The family releases in lockstep; every gem pins its siblings at the same version.

- Domain in, theme out: point the generator at a public website and get a poetry theme built from the colors, type, radii, and spacing it finds.
- Token derivation adapted from the agentcn extract-design-md recipe, so the result reads as a design document as well as a theme.
