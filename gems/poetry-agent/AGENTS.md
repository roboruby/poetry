# AGENTS.md — poetry-agent

The agent-interop gem: every surface through which an agent reaches the
component contract. Two ship:

- **The MCP server** — `exe/poetry-agent`, a boot-free, read-only stdio
  MCP server (JSON-RPC 2.0, no SDK dependency) over the registry and the
  llms surfaces, for coding agents (`lib/poetry/agent/mcp/`: server,
  bundled, http). It moved here from poetry-core; core keeps the `tool` DSL
  the server projects.
- **The WebMCP runtime** — `registerPoetryAgent(application)` registers a
  rendered component's declared tools with the browser's
  `document.modelContext` (`app/javascript/poetry/agent/`: the adapter over
  the browser API, the webmcp and webmcp-form controllers), plus
  declarative forms, the origin-trial middleware
  (`lib/poetry/agent/webmcp/origin_trial.rb`), and opt-in registration.

## Gates

- `bundle exec rake` — the default chain: `test`, `rubocop`, `yard:verify`,
  `yard:coverage` (every public object documented; floors at 0).
- `npm test` — vitest over the controllers and the adapter (+ the
  controllers_manifest drift gate); `npm run manifest` regenerates
  `config/controllers_manifest.json` after any controller surface change.

## Conventions

- Tools are declared in the component gems with poetry-core's `tool` DSL
  (validated at class load against the controllers manifest); this gem
  never defines tools of its own — it registers, describes, and executes
  what the registry declares. A tool is executed only through its resolved
  Stimulus action.
- Registration is opt-in per rendered instance (the `webmcp:` payload); the
  registrar guards at runtime and `Poetry::Agent.config.registration_budget`
  (default 20; it writes through to poetry-core's
  `webmcp_registration_budget`, which the contract puts on each opted-in
  root) caps how many tools one page registers. Mutating tools carry
  their safety annotation; the MCP server is read-only.
- `Poetry::Agent::AGUI` is a CLIENT of AG-UI, never a server (Ruby has
  two): `Transcript` is the one event fold, `Relay` is view-free (the host
  renders rows; `append_render` wraps a first appearance in its list item),
  events may arrive camelCased or snake_cased (`AGUI.field`), and client
  tool names are the registrar's `poetry.{instance}.{tool}` so the bridge
  executes them in-page without `modelContext`.
- `Poetry::Agent::A2UI::Catalog` follows the v1.0 catalog rules (the ten
  top-level keys, `$defs` = `anyComponent` + `anyFunction`, external refs
  into `common_types.json` only); the content-block heuristic is
  `requires_content` / `requires_any` content / an `elements` content cell.
- The registrar validates every call in code (required, unknown, type,
  enum) and answers problems as `Error: ...` strings; a result is the
  action's returned state (core's tool-bound actions return it) or a
  done marker. `adapter.js` is the only file that knows the browser's
  shape: Chrome 151 serializes `inputSchema` and parses only JSON-string
  arguments (spec issue #278) - the adapter normalizes both, so never call
  `document.modelContext` directly elsewhere.
- Tool names follow the WebMCP spec grammar (1–128 chars of
  `[A-Za-z0-9_.-]`; `poetry.{instance}.{action}`); `registerTool` rejects
  duplicate names, so instance ids must be stable and unique on the page.
- `config.origin_trial_tokens` feeds the origin-trial middleware; keep
  tokens out of the repo — they ride host configuration.
- `poetry check` (poetry-core's Check, run through poetry-ui's `rake poetry:check`)
  carries the WebMCP rules (`webmcp-autosubmit`, `webmcp-duplicate-name`, `webmcp-name`, `webmcp-without-tools`); the docs
  site's /webmcp page is the browser-verified reference.

## Standing rules

Releases: versions move in lockstep across the family, with poetry-core
pinned exactly (`= VERSION`); bumps happen only on the maintainer's
explicit go. Publishing runs only through the tag-triggered release
workflow (OIDC trusted publishing) — never `gem push` by hand. The
CHANGELOG stays bare until 0.1.0; commit messages carry the record.
Siblings ride local paths in the Gemfile only when checked out beside this
repo; the lockfile is not committed; the npm tooling files never ship.

Naming: "Poetry" is the product in prose; gem names, constants, the
`poetry-agent` executable, and identifiers stay as they are.

Third-party code: adapt only from MIT-compatible sources (MIT/ISC/BSD;
Apache-2.0 carries its notice). Copyleft (GPL/LGPL/AGPL), restricted-use,
and commercial sources are patterns-and-ideas only — never code. Every
adaptation notes "Adapted from an MIT-licensed source (source and
license in THIRD_PARTY_NOTICES.md)" in its class doc and gets a
THIRD_PARTY_NOTICES.md section — the source URL lives there, never in
code.
