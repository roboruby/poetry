# Changelog

## [0.1.1] - 2026-09-08

Lockstep release with the family; no changes in this gem.

## [0.1.0] - 2026-09-05

Initial public release. The family releases in lockstep; every gem pins its siblings at the same version.

- The migration bridge from simple_form to poetry: one initializer maps simple_form's input types onto classes that render whole poetry Fields through `Poetry::Ui::FormBuilder`, so existing `f.input` calls keep working.
- String, text, numeric, password, boolean, date and time, file, and collection inputs; existing `simple_form.*` translation keys keep resolving.
- The `poetry:simple_form:install` generator writes the initializer.
