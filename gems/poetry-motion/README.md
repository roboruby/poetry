# poetry-motion

Poetry's motion tier: opt-in animated effects for Rails, built on Poetry
behaviors. It is in development and not released.

The server renders every effect's finished state, so a page reads right
before any JavaScript runs, in print, and with reduced motion. Motion is
enhancement on top.

- **The engine loads on demand.** The framework-free `motion` API (MIT) is
  vendored as one file of about 28 KB gzipped and pinned without preload. A
  page with no motion element never fetches it; the first behavior that
  needs it calls `loadEngine()`.
- **One motion policy.** `@poetry/motion/policy` decides reduced motion
  once (the user's setting, or `data-motion="reduce"` or `"full"` on
  `<html>`), reads the motion tokens, returns animated elements to their
  server-rendered finished state before Turbo caches a page, and keeps layout
  animation out of the way of a Turbo visit transition.
- **Tokens in the theme.** `--motion-duration-*`, `--motion-ease-*` and
  `--motion-spring-*`, overridden like any other token.

CSS keeps doing what CSS does: presence, hover and focus transitions and
keyframe loops stay in poetry-core and plain CSS. This gem is for springs,
scroll-linked values, pointer input, drag and layout animation.

## Install

```ruby
gem "poetry-motion"
```

```sh
bin/rails g poetry:install --motion
```

The installer copies the tokens stylesheet into `app/assets/tailwind/poetry/`,
imports it, and registers the motion controllers in
`app/javascript/controllers/index.js`.

## Development

```sh
bundle exec rake   # Ruby tests, RuboCop, then npm test
npm run vendor:motion   # rebuild the engine after a motion bump
```

The JS suite drift-gates the committed engine, holds it to 30 KB gzipped,
and proves nothing imports it statically.
