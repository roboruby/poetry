# poetry-agent

The agent-interop gem of the [poetry](https://github.com/roboruby/poetry) component library: every surface through which an agent reaches the component contract, projected from the one registry the other gems build.

Five surfaces ship:

- **The MCP server** — `bundle exec poetry-agent`, a boot-free, read-only stdio MCP server (JSON-RPC 2.0, no SDK dependency) for coding agents in Claude Code, Cursor, VS Code, Zed, and RubyMine: `compose`, `build_page`, `list_components`, `describe_component`, `check`, `list_blocks`, `describe_block`, `list_recipes`, `get_skill`, `guidance`. The same server mounts over HTTP at a same-origin path (`mount Poetry::Agent::MCP::HTTP.new => "/mcp"`) for in-page bridges.
- **The WebMCP runtime** — `registerPoetryAgent(application)` registers a rendered component's declared tools with the browser's `document.modelContext` when a call opts in (`poetry_tabs(webmcp: "sections")`), dispatching each call to the component's own Stimulus action; declarative forms (`poetry_webmcp_form`) answer agent-invoked submits through `SubmitEvent.respondWith`; an `Origin-Trial` middleware serves trial tokens.
- **The AG-UI relay** — `Poetry::Agent::AGUI`: a Rails-side client of the Agent-User Interaction protocol. `Client` runs an agent endpoint and yields its events, `Transcript` folds them into chat-shaped messages (text, reasoning, tool calls with state, activities), shared state (JSON Patch), interrupts, and the tool calls the browser must execute, and `Relay` renders every change as a versioned Turbo Stream through the host's own row partial. A rendered component's declared tools are advertised as the agent's frontend tools (`Poetry::Agent::AGUI.tool_descriptor`) and executed by the `poetry--agent--agui-client-tool` bridge through the same registrar WebMCP uses, with or without a WebMCP browser.
- **The A2UI catalog** — `Poetry::Agent::A2UI::Catalog.from_registry(root)` projects the component registry into an A2UI v1.0 catalog document (JSON Schema per component: style axes as enums, options as typed properties, slots as child references, the content block as `text` or `children`), so any A2UI agent generates against Poetry's vocabulary and a renderer validates against the same document.
- **The A2UI renderer** — `Poetry::Agent::A2UI::Session` folds the A2UI envelope (`createSurface`, `updateComponents`, `updateDataModel`, `deleteSurface`) into surfaces and answers what it cannot honor with the spec's renderer-to-agent errors; `Renderer` renders a surface through the host's view context with a catalog binding — the spec's basic catalog mapped onto Poetry's components (`Catalogs::Basic`) or Poetry's own catalog rendered straight from the registry (`Catalogs::Native`); `Streams` delivers every change as a versioned Turbo Stream. A surface renders as a form: bound inputs are named by their data-model pointer, every agent action is a submit button, and `Session#action` turns the submitted form into the spec's `action` message (two-way binding syncs on the action, as the spec asks). Functions (`formatString`, `formatCurrency`, …) and `checks` beyond what the browser enforces natively are the next slice.

## Install

```ruby
gem "poetry-agent"
```

```js
// app/javascript/controllers/index.js
import { registerPoetryControllers } from "@poetry/controllers"
import { registerPoetryAgent } from "@poetry/agent"
registerPoetryControllers(application)
registerPoetryAgent(application)
```

Loading the gem is the integration: the engine registers its controllers manifest with poetry-core (so `webmcp:` roots validate at render), pins `@poetry/agent` in the importmap, and mounts the origin-trial middleware.

```ruby
# config/initializers/poetry_agent.rb
Poetry::Agent.configure do |config|
  config.origin_trial_tokens = ENV.fetch("WEBMCP_ORIGIN_TRIAL_TOKENS", "").split(",")
  config.registration_budget = 20
end
```

## Safety by construction

Nothing registers until a rendered instance opts in. Tools are read-only unless declared `mutating: true`. `autosubmit` is GET-only. Registrations are budgeted per document, never repeated for an unchanged payload, never made under Turbo's cache preview. Every call is validated in code (required, unknown, and mistyped parameters, enum membership) and problems return as descriptive strings so an agent corrects its call; results carry the resulting state. An agent-invoked form answers through `respondWith`, then the page catches up with the answer (a Turbo visit for a GET, a rendered stream, the redirect target of a POST).

## Development

```bash
bin/setup && bundle exec rake   # tests, rubocop, yard gates
npm install && npm test         # the runtime's JS tests (vitest + jsdom)
npm run manifest                # regenerate config/controllers_manifest.json
```

## License

MIT.
