# AGENTS.md — poetry-jumpstart_pro

The Jumpstart Pro installer: `bin/rails g poetry_jumpstart_pro:install`
copies Poetry recreations of a Jumpstart Pro app's views into the host's
`app/views/` (79 templates in 13 categories, shadowing the engine's
originals through the normal view lookup), then reconciles Jumpstart's
stylesheets with Poetry's, installs the pagination and toast helper, adds
Poetry's styles to Madmin and updates the selectors of Jumpstart's own tests
that assert on replaced markup. It targets Jumpstart Pro on Rails 8
authentication (the `users/*` screens, `content_for :title`, `@page`
pagination). This repo is PUBLIC; the upstream product is commercial, and
the gem's license safety rests on the rules below.

## Gates

- `bundle exec rake` — the tests, `yard:verify` and `yard:coverage`.
- `JUMPSTART_PRO_PATH=/path/to/jumpstart-pro-rails bundle exec rake` adds
  the guards that read a local, licensed Jumpstart Pro checkout in place:
  the drift guard (every template shadows a view the engine ships, the auth
  routes exist), the license guard (no template shares more than half of its
  five-token runs with the original) and the translation check (every key a
  template looks up without a default exists in Jumpstart's or Rails'
  English locale). They skip without the variable, as on CI. Never vendor
  or commit any of the checkout.
- `bundle exec rubocop`.
- Before a release, run the installer in a scratch copy of the latest
  Jumpstart Pro and run its `bin/rails test`, `bin/rails test:system` and
  `bin/rails poetry:check`.

## The one hard rule

**Never copy Jumpstart Pro markup, view code, copy text or comments into
this repo.** Templates are written fresh with Poetry components against the
same route, ivar, local and i18n contract; the private checkout is consulted
for behavior parity only. A screen that cannot be re-expressed without
copying stays out of scope: the checkout processor forms, the payment method
forms for Braintree and PayPal, the agreement content partials and the
mention list stay Jumpstart's. Copy the gem needs of its own goes through
`t(".key", default: "...")` in this gem's words.

## Conventions

- Every template opens with `<%# Poetry recreation of Jumpstart's <path>: ... %>`;
  a strict-locals comment goes after it.
- Templates compose `poetry_*` helpers and `Poetry::Ui::FormBuilder`, never
  hand-written `cn-*` classes. The one exception, `users/_user`, styles with
  token classes because Action Text strips a component's data attributes.
- A submit that Jumpstart's own tests click carries `name: "commit"`.
- An `_html` key with a String default does not come back html_safe; compose
  markup in ERB instead.
- The stylesheet edits (`Poetry::JumpstartPro::Stylesheets`) and test edits
  (`Poetry::JumpstartPro::TestEdits`) are pure and idempotent; a new one
  ships with a test.

## Standing rules

A family gem: it releases in lockstep with the rest of Poetry from 0.1.12,
listed in `Releaser::GEMS`, its version stamped from the root `VERSION`
and its siblings pinned exactly. The release train builds, signs and
pushes it; never `gem push` by hand and never move or delete a `v*` tag.
Changelog notes head the next version's undated `## [X]` heading.

Third-party code: adapt only from MIT-compatible sources (MIT/ISC/BSD;
Apache-2.0 carries its notice). Copyleft, restricted-use and commercial
sources, Jumpstart Pro above all here, are patterns-and-ideas only, never
code.
