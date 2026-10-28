# Changelog

## [0.1.14]

### Added

- `describe_component` prints one line per behavior the component uses.
- The AG-UI `Transcript`'s text and reasoning parts carry `state:`: `:streaming` until their END event (or the run's end) closes them, then `:done`; a `MESSAGES_SNAPSHOT`'s parts arrive `:done`. Closing a part re-renders its row through the relay, so a reasoning step reads "Thinking" while it streams and "Thought" once it closes.

- The AG-UI run input declares the protocol version it speaks, `protocolVersion: "1.0"` (`Poetry::Agent::AGUI::PROTOCOL_VERSION`), as AG-UI 1.0 requires; `RunInput.build(protocol_version: nil)` omits it for an agent known to predate the field.
- `Transcript#runs` keeps every run on the stream, so a first run's failure survives a second run.
- `Transcript#add_message` records a message the host sends (the user's turn, a tool result, a system prompt), so `messages_for_input` carries the whole conversation: no event echoes the user's own turn, and a stateless agent never saw it again.
- `Relay` takes a row a snapshot renamed or dropped off the page (a remove stream; `remove_targets:` names what to remove, such as the scroller item around the row), so a message no longer shows twice. `TurboStream.remove_all(selector)` builds the stream.
- User and tool messages carry content parts (text, image, audio, video, document) end to end: `RunInput.user_message` and `tool_message` take a list of parts, a snapshot's parts arrive as text and `:media` parts, and `messages_for_input` sends them back as parts.

### Changed

- The released gem serves its JavaScript minified, as poetry-core does, from `dist/javascript` with a source map beside each file.
- The MCP check tool warns on a renamed Lucide icon with its current name instead of rejecting it.
- BREAKING: `RunInput.resume_entry` requires `status:` and takes only AG-UI 1.0's two, `"resolved"` (the answer in the payload) and `"cancelled"`, raising `ArgumentError` otherwise. The former `"approved"` / `"rejected"` are rejected by 1.0 agents.
- A reasoning message is a message of its own (role `reasoning`), as in AG-UI 1.0, and travels back in `messages_for_input`, as do system and developer messages; only activity messages stay behind.
- A tool call without a `parentMessageId` gets an assistant message of its own under the call's id, as the reference client does, instead of joining whichever message came last.
- A `MESSAGES_SNAPSHOT` reconciles by id, as AG-UI 1.0 specifies, instead of replacing everything: a message it carries replaces the copy with the same id in place, one never seen is appended, and one it leaves out is dropped, except activity and reasoning messages, which a snapshot carrying none of that role keeps. Streamed reasoning used to vanish at a closing snapshot.
- A run that finishes with the cancelled outcome reads `:cancelled`, neither success nor failure; `ended?` counts it.
- A tool call's arguments go back to the agent exactly as they streamed (an argument-less call sends `""`), and a tool result's message keeps the result's own `messageId` and its content parts.

### Fixed

- An `ACTIVITY_DELTA` after a `MESSAGES_SNAPSHOT` no longer raises `NoMethodError`: a snapshot carrying no activity keeps the activities, so the delta applies; one naming an activity no message holds is skipped and recorded in `unknown_events`.
- A frontend tool called through `TOOL_CALL_CHUNK` events waits on the browser once the run ends; it used to stay loading and never reach the bridge.
- A snapshot's multimodal user content is kept as parts instead of becoming a Ruby `inspect` string.
- A `null` state snapshot applies (state may be any JSON value), and a closed tool call reopened with the same id appends its arguments instead of minting a second call. Arguments arriving for a closed call are ignored instead of raising, and a `TOOL_CALL_CHUNK` continuing a call a snapshot restated reopens it.
- A client tool waiting on the browser keeps waiting through a `MESSAGES_SNAPSHOT` (it showed loading again), and follows its call when the snapshot renames the message.

## [0.1.13] - 2026-10-13

### Changed

- Version bump with the family; no changes in this gem.

## [0.1.12] - 2026-10-07

### Changed

- Version bump with the family; no changes in this gem.

## [0.1.11] - 2026-10-05

### Changed

- Version bump with the family; no changes in this gem.

## [0.1.10] - 2026-10-03

### Changed

- Version bump with the family; no changes in this gem.

## [0.1.9] - 2026-09-30

### Changed

- Version bump with the family; no changes in this gem.

## [0.1.8] - 2026-09-22

### Changed

- Version bump with the family; no changes in this gem.

## [0.1.7] - 2026-09-20

### Changed

- Version bump with the family; no changes in this gem.

## [0.1.6] - 2026-09-20

### Changed

- The gem is developed in the Poetry monorepo, roboruby/poetry, under `gems/poetry-agent`; the gemspec's source, changelog and issue links point there, and its file list no longer needs git on the machine (a path gem inside a slim image lists the same files).
- The gem describes Poetry as the AI-native frontend framework for Rails.

## [0.1.5] - 2026-09-18

### Added

- The controllers manifest carries the prose beside each controller: its purpose (a JSDoc block above the class), the meaning of every value, and a summary of every action method, harvested when the manifest is generated; `rake stimulus:docs` holds the count of gaps at a committed floor, now zero.

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
