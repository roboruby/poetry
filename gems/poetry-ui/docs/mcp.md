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
| `list_components` | — | every component, its `poetry_*` helper, and whether it is interactive |
| `describe_component` | `name`, `detail: brief\|detailed\|full` | the contract — progressive disclosure so an agent loads one component, not all 38 |
| `check` | `source` | a verdict (PASS/FAIL) + findings: unknown component/option/variant/wiring, raw colors |

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

## Scope (v1)

This cut is the read/verify surface. The heavier roadmap from the design notes
— `verify_screen` running the eval gate array, `component://` artifact
resources (rendered previews, screenshots), tag browsing, and a StreamableHTTP
transport — is deliberately not here yet. Because every tool is read-only,
there is no mutation surface to guard in v1; when write/operate tools arrive,
authorization is enforced inside tool execution, never the client UI.
