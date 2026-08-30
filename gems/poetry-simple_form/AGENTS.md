# AGENTS.md — poetry-simple_form

The migration bridge from simple_form to Poetry: an opt-in initializer
re-maps simple_form's input types onto classes under
`lib/poetry/simple_form/inputs/` (string, text, numeric, password, boolean,
date/time, file, collection) that render whole Poetry Fields THROUGH
`Poetry::Ui::FormBuilder`, so existing `f.input` calls keep working with
the quartet (label / hint / error / aria) derived from the model. The end
state is `form_with(model:, builder: Poetry::Ui::FormBuilder)`; this gem
exists to make getting there boring, then to be removed.

## Gates

- `bundle exec rake` — the default chain: `test` (against `test/dummy`),
  `yard:verify`, `yard:coverage` (every public object documented; floors at
  0). RuboCop is not in this gem's bundle — run it from a sibling checkout
  if you touch more than a line.

## Conventions

- Render THROUGH the builder, never around it: an input class resolves the
  simple_form type and hands the field to `Poetry::Ui::FormBuilder`;
  simple_form contributes type resolution only — its wrapper tree is
  bypassed by design (a flat wrapper cannot express the Field quartet).
  Do not re-implement a Field here.
- `lib/generators/poetry/simple_form/install/` writes the initializer that
  performs the re-mapping; the mapping is the whole public surface.
- Existing `simple_form.*` i18n keys (labels/hints/placeholders) must keep
  working — the builder reads them as a fallback chain; a change that
  breaks that chain breaks every migrating app.

## Standing rules

Releases: versions move in lockstep across the family, with poetry-ui
pinned exactly (`= VERSION`); bumps happen only on the maintainer's
explicit go, and this gem publishes after poetry-ui is live. Publishing
runs only through the tag-triggered release workflow (OIDC trusted
publishing) — never `gem push` by hand. The CHANGELOG stays bare until
0.1.0; commit messages carry the record. Siblings ride local paths in the
Gemfile only when checked out beside this repo; the lockfile is not
committed.

Naming: "Poetry" is the product in prose; gem names, constants, and
identifiers stay as they are.

Third-party code: adapt only from MIT-compatible sources (MIT/ISC/BSD;
Apache-2.0 carries its notice); simple_form itself is a runtime dependency,
not adapted code. Every adaptation notes "Adapted from an MIT-licensed
source (source and license in THIRD_PARTY_NOTICES.md)" in its class doc
and gets a THIRD_PARTY_NOTICES.md section — the source URL lives there,
never in code.
