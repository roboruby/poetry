# poetry-agent (MCP server)

`poetry-agent` exposes the live poetry component contract to a coding agent
over the Model Context Protocol, so the agent queries what poetry *actually*
ships instead of guessing — and verifies its own markup before you review it.

It is **read-only**, **boot-free** (it reads the committed registry, so it
starts instantly — no Rails), and projects the same source every other poetry
surface does: the registry, `poetry check`, and llms.txt.

## Tools

| Tool | Args | Returns |
|------|------|---------|
| `compose` | `brief` | the FIRST move for every brief: routes to the matching vetted block (source inline) or the matching components |
| `build_page` | `intent`, `step`, `source` | the GUIDED build for a whole screen: a five-step workflow (probe → plan → direct → snippets → verify), one step per call, done only on a `check` PASS |
| `list_components` | — | every component, its `poetry_*` helper, and whether it is interactive |
| `describe_component` | `name`, `detail: brief\|detailed\|full` | the contract — progressive disclosure so an agent loads one component, not the whole catalog |
| `check` | `source` | a verdict (PASS/FAIL) + findings: unknown component/option/variant/wiring, raw colors, icon membership, arity, required slots, any-of contracts |
| `list_blocks` | — | the vetted composed-screen catalog |
| `describe_block` | `name` | one block's contract AND full ERB source, ready to adapt |
| `get_skill` | `name: poetry\|poetry-design`, `file` | the installed skills served at runtime — SKILL.md + file index, or one reference file — for hosts that cannot write `.claude/skills/` |
| `guidance` | `topic` | curated composition guidance; `deciding` = the which-component decision tree |

`describe_component` accepts either the short name (`button`, `command_dialog`)
or the full registry path. `full` detail adds the Stimulus wiring surface
(controllers, targets, values, actions in the Base UI vocabulary) and the
agent rules.

## Wiring it up

From an app that has poetry installed:

**Claude Code**

```
claude mcp add poetry -- bundle exec poetry-agent
```

**Cursor / any MCP host** — add a stdio server whose command is
`bundle exec poetry-agent` (run from the app directory).

## The loop it closes

1. `list_components` → the agent sees the catalog.
2. `describe_component` → it loads the one contract it needs.
3. It writes ERB.
4. `check` → it verifies the markup against the contract and self-corrects
   **before** the code is rendered or reviewed.

That is the "verify against, not just read about" bet: the same `poetry check`
that runs in CI and the eval is one tool call away inside the agent's own loop.

## The guided build (`build_page`)

For a whole screen, `build_page` runs a guided workflow instead of a single
route. Call it with the `intent`; the entry routes on your verb (a *review* or
*harden* request stays read-only — an audit never becomes an edit), and an
*implement* intent starts the sequence:

1. **probe** — reads the host (`config/poetry_components.yml`, the installed
   theme, css mode, importmap-vs-bundler) and reports setup gaps.
2. **plan** — matches the intent to a page architecture: section order, the
   states a real screen handles (loading, both kinds of empty, error), the edge
   cases, the components, and the vetted block to start from.
3. **direct** — the creative direction, derived from the installed theme (poetry
   sells coherence, not a freeform trend pick).
4. **snippets** — the block/components to start from (routed exactly as `compose`).
5. **verify** — runs `check`; the workflow is **done only on a PASS**, an
   executable verdict rather than a claim.

Each call returns one step and the exact next call; out-of-order steps are
answered, never refused, so à-la-carte use keeps working.

## Scope (v1)

This cut is the read/verify surface. The heavier roadmap from the design notes
— `verify_screen` running the eval gate array, `component://` artifact
resources (rendered previews, screenshots), tag browsing, and a StreamableHTTP
transport — is deliberately not here yet. Because every tool is read-only,
there is no mutation surface to guard in v1; when write/operate tools arrive,
authorization is enforced inside tool execution, never the client UI.
