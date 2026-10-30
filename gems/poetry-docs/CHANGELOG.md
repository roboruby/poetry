# Changelog

## [0.2.0]

### Added

- The MCP Apps guide (`/mcp-apps`): what an app is, serving a Poetry-rendered document as a `ui://` resource on the official `mcp` gem, answering tool calls with server-rendered fragments, the page's attributes and the bridge, the two asset strategies and what each host does with them, the host's theme and style variables, what the model sees, and how to try it in Claude Desktop; with its markdown mirror.
- The MCP App demo (`/demos/mcp-app`): a plan picker this site's own MCP server serves beside its roster, hosted by this site's own `Poetry::Agent::Apps::Host` over `/mcp` (the page calls `show_plans` through the host, the app's own `choose_plan` goes through the host's endpoint) with the bridge's traffic logged both ways; the same document renders in Claude Desktop through `mcp-remote`.
- The AG-UI relay's fallback for MCP Apps: an `mcp-apps` activity (what AG-UI's MCP Apps middleware sends for a tool that has an app) renders as a Trace step under the tool's words, "app not shown", with the result's text and a note naming the app; the relay demo's plans tool has one, and the AG-UI guide and its mirror say how the activity reads and what a host would do.
- The MCP Apps guide names the upstream watch (`rake upstream:watch`) beside the vendoring manifests.
- The MCP Apps guide's lazy authorization paragraph: `protected_tools:` for a mount whose open tools answer anyone and whose protected tools challenge on the call, and how to walk it with curl and Claude Code.
- The MCP Apps guide's Per-user authorization section: the resource server on `Poetry::Agent::MCP::Auth`, the verifier's three forms, what Claude, ChatGPT, Cursor and mcp-remote need from the authorization server (PKCE S256, discovery metadata, a client id by registration or a client ID metadata document, their redirect URIs), and the Doorkeeper recipe with the two endpoints it lacks; the MCP server guide's HTTP section points to it; both mirrors.
- The MCP Apps guide's Host section: display modes (inline, fullscreen, pip: the frame moves without reloading, both sides may ask, the page may refuse) and per-user credentials (a server's `credentials:`, `Host::OAuth` as the `mcp` gem's OAuth client over the app's own storage, the callback route, the 401 the frame announces); the plans app declares every mode and offers Expand from inside, and the demo's page-side Fullscreen and Picture in picture buttons.
- The MCP Apps guide's Host section: other servers' apps in your page on `Poetry::Agent::Apps::Host`, the two-origin sandbox and the inline mode, the endpoint and per-user credentials, the frame in a relay row; its mirror and the agent library row. The MCP App demo runs on the real host now (this site hosting its own plans app, in the inline mode, the bridge logged both ways), and the AG-UI Relay demo renders the plans app's frame for the `mcp-apps` activity, with the app's real result in the replay.
- The Islands library page: what an island is, the module contract, fill and flow with two live islands (a canvas clock and a counter that writes to its hidden input), the form seam, the Turbo lifecycle and the check, with its markdown mirror; the poetry-island and @poetry/island API pages.

- `config.community_registry` names a directory of community items: `/r/<name>.json` serves one when the gems ship no item of that name, and `/r/community/registry.json` serves their index. The UI library page explains the community fallback.
- A Motion section: one page per poetry-motion effect at `/motion/<slug>`, the Motion library guide (the payload, the motion policy, the tokens, the ten behaviors and when motion is just CSS), the poetry-motion API pages, and the effects in the sidebar, search and llms.txt.
- Component and chart pages show a Behaviors table beside Wiring: each behavior the component uses, where it is wired and what it does. The table says Poetry behaviors are not Herb's client behaviors.
- A page for each new icon set (Tabler, Hugeicons, Phosphor, Heroicons, Simple Icons) under /icons, with a live sample of every style, and the Lucide page updated for 1.57.0 and its aliases. The examples use `trash`, Lucide's current name for `trash-2`.
- Pages for poetry-solar and poetry-blode under /icons; an icon set with an attribution gets an Attribution section with its visible credit line.
- The AG-UI Relay demo page has a States example: the relay's own rows for a turn with image and document attachments, a tool result made of content parts, a call the person declined, a subagent that failed, a run the agent cancelled, and a stream the page stopped reading, each built from real AG-UI 1.0 events.
- The AG-UI Relay guide covers what a message carries (metadata, subagent attribution, encrypted reasoning, a run's usage and unanswered calls), a frontend tool that asks first (`confirm: true`, the approval prompt, `decline_client_tool`), and stopping a run (`transcript.truncate` against a cancelled outcome); the recipe passes `approval:` and truncates a stream that broke off. The llms mirror says the same.

### Changed

- The MCP guide, the agent library page and the editors page say the server runs on the official `mcp` gem, and the guide's HTTP section describes the stateless JSON transport, `Accept: application/json`, `allowed_origins:` and `Server#mcp`.
- The A2UI Surface demo renders a v0.9 surface, a feedback card shaped as AG-UI's A2UI middleware sends one, beside its v1.0 surfaces; its action and the agent's reply speak v0.9.
- The A2UI guide names `session.capabilities(inline: true)`.
- The A2UI guide's checks section says when the browser tells the user of a failure (once they have edited the input, a button's reason once any input is edited) and that a streamed re-render judges the edited inputs again.
- The A2UI guide's strict validation covers the schema checks and a catalog binding's `document`.
- The A2UI guide and its markdown mirror cover both protocol versions: how each spells bindings and calls, the version every message names, the catalogs bound per version and the refusal of an unknown one (`fallback_catalog:`), per-component and per-call catalogs, strict validation, `openUrl` running only from a gesture, a function's answer or error inside its response, `user_activated:`, `session.status`, `session.capabilities` and `session.renderer_data_model`.
- The A2UI catalog is served in both versions: `/a2ui/v1_0/catalog.json` (and `/a2ui/catalog.json`) for v1.0 agents, `/a2ui/v0_9/catalog.json` for v0.9 ones.
- The A2UI demo, the AG-UI Relay demo's trial surface and the A2UI guide's samples speak A2UI v1.0 as agents now send it: version `"1.0"`, `@path` bindings and `@call` calls.
- The AG-UI Relay and Chat Replay demos render agent activity on Trace and CodeBlock, after shadcn's Trace chat example. Each run of reasoning and tool calls is one Trace: reasoning reads "Thinking", open, while it streams and "Thought" after; a tool call's words and status follow its state ("Looking up plans", "Looked up plans", waiting in the browser, failed); a finished call discloses its input and output in small CodeBlocks. An approval is an Item prompt with Deny and Approve, and a Chat Replay turn waits as a running "Thinking" line. The AG-UI Relay page's partial samples show the same mapping.
- The AG-UI Relay guide has a section on what the client checks: the pipeline's order, `ProtocolError` and `ProtocolWarning`, lenient mode, `max_protocol_version:`, and why a relay fed by the client takes `pipeline: nil`. The recipe logs warnings through `on_warning:`, the resume sample passes `interrupts:` so a list that leaves one out raises, and the Interrupts section says the pipeline names a pre-1.0 interrupt. The llms mirror says the same.
- The AG-UI Relay demo folds its earlier runs through a pipeline, as the guide says a transcript is fed.
- The AG-UI Relay demo's tab switch asks first: its prompt waits in the page, Approve runs it and Deny tells the agent no (the step reads "Denied: switching to the pricing tab"). Its trial is started by a billing subagent whose call nests under a step naming it.
- Agent activity rows show a user's images and documents as Attachment chips, a tool result's images beside its text output instead of base64 in a code block, a declined call as denied rather than failed, a subagent's work nested under a step naming it, and a waiting step in a cancelled or broken-off run as stopped, with a Marker saying so, instead of running forever.
- The AG-UI Relay guide and its llms mirror speak AG-UI 1.0: the resume sample answers an interrupt with `status: "resolved"` and the decision in the payload (`cancelled` abandons it), user and tool messages take content parts, a reasoning message renders as its own row and travels back in `messages_for_input`, and `Transcript#runs` keeps every run. The recipe records the user's turn with `transcript.add_message` before each run (it used to send only the new message, so later runs lost the conversation), the relay removes a row a snapshot drops (`remove_targets:`), and the Interrupts section says real interrupts often carry no `message`.
- The CodeBlock wrap example logs a redirect to a signed URL, a token with no break point, so it shows `wrap: true` breaking one.

### Fixed

- The A2UI Surface demo's standalone example (`/examples/demos/a2ui-surface/default`) renders: it raised `NoMethodError` for want of the session the demo page prepares.
- The AG-UI Relay demo's controls (the approval prompt, the replay link) follow the run's reply instead of sitting above it: each streamed message used to append after them.
- The AG-UI Relay demo's scripted agent emits conformant AG-UI 1.0: each `RUN_STARTED` declares `protocolVersion`, `REASONING_MESSAGE_START` carries its required `role: "reasoning"`, and the reasoning message has an id of its own instead of sharing the text message's. A 1.0 client rejected run one outright.
- The AG-UI Relay demo's interrupt prompt falls back to the interrupt's reason when it carries no message, and a message a snapshot drops leaves the scroller with its item.
- The AG-UI Relay demo's standalone example (`/examples/demos/agui-relay/default`) renders: it raised `NoMethodError` for want of the history the demo page prepares.

## [0.1.13] - 2026-10-13

### Added

- `Poetry::Docs::HostLayout`: a host application's own controller includes it to render inside the docs layout, with the sidebar, header, search and meta tags, so pages the host serves beside the docs (the registry pages planned for poetryui.com) look like the rest of the site. The layout and the site nav reach the engine's routes through its mount proxy, `poetry_docs.`, and the shared partials moved to `poetry/docs/shared/` so a host's own `shared/` partials never stand in for them.

### Changed

- The theming guide describes the design import's faint-edge warning.
- The UI library page says that `poetry:add` refreshes the controllers manifest for an item with a Stimulus controller.

## [0.1.12] - 2026-10-07

### Added

- The poetryui.com documentation as a mountable engine, `Poetry::Docs`, moved from the repository's `site/` app with its guides, galleries, demos and machine surfaces intact: its own layouts, a prebuilt stylesheet with the nine-theme registry, its own importmap entry point and Stimulus application, and file reads that resolve against the engine's root. A host mounts it at the root of its docs hostname and takes it from the repository at a release tag; the engine is versioned with the family and not published. The dummy host under `test/dummy` serves it for authoring and the tests.
- A Jumpstart Pro library page, `/libraries/jumpstart-pro`, the guide to poetry-jumpstart_pro from install to removal, with its Markdown mirror; the Installation guide's "Installing into a Jumpstart Pro app", the Pagination guide's Jumpstart Pro setup, and a Jumpstart Pro section in the agent install instructions.

### Fixed

- The pagination guide renders in any host. The engine requires the guide's paginators itself (pagy, kaminari's core and Action View parts, will_paginate's collection, never their Active Record extensions), where before only the dummy host did, so a host that only mounts the engine raised `NameError` on `/pagination`.

