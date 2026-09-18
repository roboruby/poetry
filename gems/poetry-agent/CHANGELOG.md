# Changelog

## [0.1.5]

### Changed

- 18 methods the reference already hid with `@api private` are Ruby-private now: each was called only by its own class or template, so the runtime enforces what the tag only stated. A host that reached one gets a NoMethodError instead of an internal that may change without notice. The tag remains on the internals the family shares between its gems and on whole internal classes.
- Every class, module and method carries a one-sentence description, private helpers included: `rake yard:coverage:all` measures the whole tree (a tag-only docstring counts as blank) and the committed floor now stands at zero.
- `describe_component` phrases any-of requirements through core's `RequiresAny`, and a test now covers the requirement and slot-facet lines.

## [0.1.4] - 2026-09-15

Lockstep release with the family; no changes in this gem.

## [0.1.3] - 2026-09-13

### Fixed

- A2UI's native catalog supplies the render-stable key as `id:` to a component that requires one (Field, MessageScroller), since an agent never sets ids. On 0.1.2 the values tier refused the missing option and the renderer swallowed the error as a warning, so a Field rendered nothing.
- The MCP `check` tool knows the app's own `poetry_*` helper methods (`app/helpers`, read boot-free), committed registry or not: the adapter `poetry:pagination` copies in no longer reads as an unknown component.

## [0.1.2] - 2026-09-13

### Changed

- A tool called without one of its declared required arguments (or with it blank) answers an error naming the argument; `check` in particular no longer reports PASS for a call that sent no `source`. `compose` and `build_page` keep answering a blank brief with their own guidance.

- `compose`, `build_page`, `list_components` and `describe_component` name an app component's helper from the registry, and an app component without one by the class to render, never an invented `poetry_` name. Once the app committed its registry that file is the truth and the component sources are not scanned; an invalid committed registry is not a root and does not crash the server.

- The WebMCP agent-focus styling (`:tool-form-active` on the form an agent fills, `:tool-submit-active` on its submit) moves here from poetry-ui's nine theme fragments, where it was identical in every theme: `app/assets/stylesheets/poetry-agent.css`, plain CSS on the theme's tokens, vendored by `poetry:install` into `layer(base)` when this gem is bundled. Hosts without poetry-agent no longer carry the rules or the two warnings the CSS optimizer prints for the origin-trial pseudo-classes on every minified build (the Rails Tailwind task minifies by default).
- Controllers manifests are registered by the same convention, boot-free: every bundled gem's and the app's own (`bin/rails poetry:stimulus:manifest`), so the `check` tool validates chart, agent and host controllers like core's.
- The server assembles from every published registry in the bundle plus the app's own committed one (`bin/rails poetry:registry`), by convention: no gem is named, a third-party engine that commits a registry is served, and an app's components describe, check and compose with full contracts under their declared helpers. `Server.from_registries` merges roots; `from_registry` remains for one.
- The MCP `check` tool knows the host application's own component helpers: a boot-free scan of the app directory's component files for `helper :name` declarations adds those names to the valid set, so the tool agrees with `bin/rails poetry:check` that the helper exists. Their option contracts stay with the booted check.

## [0.1.1] - 2026-09-08

Lockstep release with the family; no changes in this gem.

## [0.1.0] - 2026-09-05

Initial public release. The family releases in lockstep; every gem pins its siblings at the same version.

- An MCP server (stdio and HTTP) with ten tools read from the live registry: compose, build_page, list_components, describe_component, check, list_blocks, describe_block, list_recipes, get_skill, and guidance.
- The WebMCP runtime: Stimulus controllers that register component tools with the browser's agent, `poetry_webmcp_form`, a registration budget, and the origin trial middleware.
- An AG-UI client: SSE parsing, a transcript that folds events into messages, a relay that streams them as Poetry chat rows over Turbo Streams, and client tool bridging.
- A2UI on Rails: session, surface, and pointer model, the basic catalog and a native catalog for every registry component, checks and functions, the renderer, and Turbo Stream delivery with the versioned `vreplace` action.
- The `@poetry/agent` runtime registering all of it in one call.
