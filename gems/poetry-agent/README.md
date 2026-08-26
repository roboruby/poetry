# poetry-agent

The agent-interop gem of the [poetry](https://github.com/roboruby/poetry) component library: every surface through which an agent reaches the component contract, projected from the one registry the other gems build.

Two surfaces ship:

- **The MCP server** — `bundle exec poetry-agent`, a boot-free, read-only stdio MCP server (JSON-RPC 2.0, no SDK dependency) for coding agents in Claude Code, Cursor, VS Code, Zed, and RubyMine: `compose`, `build_page`, `list_components`, `describe_component`, `check`, `list_blocks`, `describe_block`, `list_recipes`, `get_skill`, `guidance`. The same server mounts over HTTP at a same-origin path (`mount Poetry::Agent::MCP::HTTP.new => "/mcp"`) for in-page bridges.
- **The WebMCP runtime** — `registerPoetryAgent(application)` registers a rendered component's declared tools with the browser's `document.modelContext` when a call opts in (`poetry_tabs(webmcp: "sections")`), dispatching each call to the component's own Stimulus action; declarative forms (`poetry_webmcp_form`) answer agent-invoked submits through `SubmitEvent.respondWith`; an `Origin-Trial` middleware serves trial tokens.

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

Nothing registers until a rendered instance opts in. Tools are read-only unless declared `mutating: true`. `autosubmit` is GET-only. Registrations are budgeted per document, never repeated for an unchanged payload, never made under Turbo's cache preview, and errors return as descriptive strings so an agent corrects its call.

## Development

```bash
bin/setup && bundle exec rake   # tests, rubocop, yard gates
npm install && npm test         # the runtime's JS tests (vitest + jsdom)
npm run manifest                # regenerate config/controllers_manifest.json
```

## License

MIT.
