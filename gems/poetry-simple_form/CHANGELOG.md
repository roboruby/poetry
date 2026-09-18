# Changelog

## [0.1.5]

### Changed

- 1 method the reference already hid with `@api private` is Ruby-private now: each was called only by its own class or template, so the runtime enforces what the tag only stated. A host that reached one gets a NoMethodError instead of an internal that may change without notice. The tag remains on the internals the family shares between its gems and on whole internal classes.
- Every class, module and method carries a one-sentence description, private helpers included: `rake yard:coverage:all` measures the whole tree (a tag-only docstring counts as blank) and the committed floor now stands at zero.

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

- The migration bridge from simple_form to poetry: one initializer maps simple_form's input types onto classes that render whole poetry Fields through `Poetry::Ui::FormBuilder`, so existing `f.input` calls keep working.
- String, text, numeric, password, boolean, date and time, file, and collection inputs; existing `simple_form.*` translation keys keep resolving.
- The `poetry:simple_form:install` generator writes the initializer.
