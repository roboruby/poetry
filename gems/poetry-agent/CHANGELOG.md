# Changelog

## [0.2.0]

### Added

- The official `mcp` gem (1.8) as a runtime dependency; its one dependency, json_schemer, arrives with it.
- MCP Apps, the author's side (`Poetry::Agent::Apps`): a Rails app's own MCP server serves Poetry-rendered screens as the interactive UI a host such as Claude shows inside its chat. A `Document` is one `ui://` resource, a complete page rendered through the app's views in the engine's layout, with the app's stylesheets and importmap linked from its origin (declared in the resource's CSP lists, so the asset pipeline and Poetry's controllers run inside the host's sandbox as they are) or, with `assets: :inline`, written into the page; `origin: :request` reads the origin of the request being served. A tool answers with a `Result`: text for the model, data in `structuredContent`, and `Fragment`s of server-rendered HTML in `_meta`, which the bridge applies to the page's `data-mcp-region` elements the way Turbo Streams apply. `Apps.capabilities`, `Apps.reader`, `Document#resource` and `#tool_meta` wire the server; `Poetry::Agent::MCP::Server#apps` serves documents beside Poetry's own roster.
- `@poetry/agent/mcp_app`, the page's half of the bridge, written from the specification with no SDK: `ui/initialize`, the tool's input and result, fragments applied by region, `tools/call` from `data-mcp-tool` buttons and forms, `ui/message` from `data-mcp-message`, `ui/open-link`, model-context updates, display modes, size reports, the host's theme, and the host's style variables mapped onto Poetry's tokens (`data-host-styles`: the structural ones by default, all, or none). The same file runs from the app's origin or inlined.
- `Poetry::Agent::Apps::Activity`: the activity AG-UI's MCP Apps middleware sends when a tool that has an app answers (`activityType` `mcp-apps`; its content the tool's MCP result, the app's `resourceUri`, the server and the tool's input), read for the fallback that shows the result's text where no host shows the app. `Activity.activity?(part)` tells a transcript part, `Activity.from(content)` reads one, and `text` joins its text blocks as the middleware does for the model.
- `Poetry::Agent::MCP::Auth`, per-user authorization for the HTTP mount on the gem's resource-server stack: `Auth.new(resource:, authorization_servers:, scopes:, verifier:)` builds the protected resource metadata (RFC 9728; `auth.metadata_app` serves it at `auth.well_known_path`), and `HTTP.new(server, auth:)` challenges a request without a token (401 naming the document and the scopes), refuses one whose token the verifier does not know (401), asks a narrow one to step up (403), and serves a good one with the token as the request's identity: `Auth.current` anywhere in the request, `server_context.auth_info` in handlers defined on the gem. The verifier is a callable over the app's own tokens (answering `{ subject:, scopes:, expires_at:, claims: }` or nil), any object answering `verify(token)`, or one of the gem's by name (`{ jwt: { jwks_uri: } }` with the `jwt` gem, `{ introspection: { ... } }`). Poetry issues no tokens.
- MCP Apps, the host side (`Poetry::Agent::Apps::Host`): other servers' apps inside a Rails page. A host knows its servers by id (a URL and headers), reads their tools and app resources through a client of Poetry's own on the standard library (JSON or event-stream answers, sessions, the raw results with `_meta`, cached), calls a tool for the page, answers an app's own requests through the extension's allowlist and the tool visibility the server declared (`host.rpc`, or `host.rpc_app` as a same-origin Rack endpoint), and serves the sandbox proxy page (`host.sandbox_app`, on a second origin under a signed token per resource, the resource's declared domains as a Content Security Policy header, framed by the host origin only) or an inline mode without a second origin. `host.frame_data(call)` is the frame the `poetry--agent--mcp-app-host` controller fills: the host half of the bridge written from the specification with no SDK (the sandbox handshake, `ui/initialize` with the page's theme and Poetry's tokens as styles, the tool's input and result, the app's requests to the endpoint, resizing, links confirmed, teardown, page events for messages, model context and display modes, a trace mode), held to the SDK's wire-compat fixtures in the tests and to Poetry's own app bridge in a loopback. The runtime's morph guard keeps a frame through a streamed re-render.
- The host's display modes: `poetry--agent--mcp-app-host` moves the frame between inline, fullscreen (fixed over the page, the page's scroll locked) and pip (a panel in the corner), the frame staying put so the app never reloads, a placeholder holding the row's height, a button and Escape bringing it back; the page offers modes with `display-modes-value`, a document declares what it handles with `display_modes:` (the app bridge sends them as `availableDisplayModes`, marks the root `data-display-mode`, and a `data-mcp-display-mode` button asks), the host grants only what both allow, the page hears `poetry:mcp-app-host:display-mode` and may change the mode, and `setDisplayMode` is the page's own call.
- Per-user credentials for a host's servers: a server's `credentials:` turns the `context:` a call passes (the signed-in person) into headers, a callable or `Poetry::Agent::Apps::Host::OAuth`, the `mcp` gem's own OAuth client toward the server (discovery, a client ID metadata document or dynamic registration, PKCE, the token exchange, a refresh on a 401 before the person is asked again) over a storage the application supplies per person and server; `host.authorized?`, `host.authorization_url` and `host.finish_authorization` drive the flow, `AuthorizationRequired` carries the URL, `RpcApp.new(host, context:)` reads the person from the request and answers an app with a 401 the frame announces as `poetry:mcp-app-host:authorize`, `frame_data(call, context:)` reads the app's resource as that person with its policy carried inside the sandbox token (so the sandbox page on the apps origin reads nothing as anyone), and `Client::Error#http_status` says what the server answered. `faraday` becomes a dependency, for the gem's client.
- `rake mcp_apps:vendor` and `mcp_apps:verify`: the MCP Apps specification and its wire schema vendored from the extension's repository with a manifest; the tests hold a document's `_meta.ui`, a tool's `_meta` and a result to the schema.
- A2UI v0.9 and v1.0 side by side, per surface (`Poetry::Agent::A2UI::Dialect`): a surface speaks the version of the message that created it, a later message must speak the same one, and everything the session sends about a surface carries its version. v1.0 binds with `{ "@path" }` and calls with `{ "@call" }`, so a plain object's `path` and `call` keys are literal data there, a literal `@` key is escaped by doubling it (`"@@type"`), and any other single-`@` key is refused; v0.9 (and `"v0.9.1"`) keeps `{ "path" }` and `{ "call" }`, requires `createSurface.catalogId`, stores the surface's `theme`, and deletes on an `updateDataModel` without a value.
- The v0.9 basic catalog, under the spec's id and the one AG-UI's A2UI toolkits send, and Poetry's own catalog under a v0.9 id (`Catalog::V0_9_ID`); every catalog binding knows its protocol version (`dialect`). A v0.9 Text's `h1` to `h5` render as headings and a TextField's `validationRegexp` becomes its `pattern`.
- The basic catalog's icon names that had no Lucide match (`warning`, `payment`, `calendarToday`, `volumeUp` and 13 more) render.
- The browser's check functions run the conformance suite's function cases in vitest.
- `Session#capabilities(versions:)`, the catalogs the renderer holds for each protocol version (`{ "1.0" => { "supportedCatalogIds" => [...] }, "v0.9" => ... }`), for an agent that resolves its catalogs against a renderer's; `Session#renderer_data_model(version:)`, the data models of the surfaces that send theirs, in one version.
- Poetry's A2UI catalog in v0.9's form: `Catalog#to_h(version: "v0.9")` and `#inline(version: "v0.9")` give the same catalog with v0.9's component wrapping, function entries and absolute common-type refs, under its v0.9 id (`Catalog::V0_9_ID`, or `v0_9_id:`), so a v0.9 agent reads a catalog in its own version.
- `Session#capabilities(inline: true)` includes each catalog's definition beside its id (A2UI's `inlineCatalogs`), for an agent that cannot fetch a catalog by its id: a v1.0 catalog as its document, a v0.9 one in the legacy inline shape the reference processors build (`Catalog.legacy_inline`: each component the common envelope plus its own properties with its name pinned, the functions a list, the theme its properties).
- A `Surface` refuses a catalog built for another protocol version among the ones it may name ("Protocol version mismatch: cannot mix catalog 'x' (v0.9) with surface version 1.0.").
- A2UI's strict validation, opt in with `Session.new(strict: true)`: an update is refused whole unless the surface keeps its `root`, references only components it holds, reaches every component from the root and nests no deeper than 50; values nest no deeper than 50 and function calls no deeper than 5; bound paths are pointers; v1.0 component ids and function names are identifiers; every call names a function its catalog declares with arguments of their declared types; and a catalog's `allowedParents` and `allowedChildren` hold (`UNALLOWED_PARENT`, `UNALLOWED_CHILD`). Its errors use the spec's codes (`INTEGRITY_ERROR`, `RECURSION_ERROR`) and wording. By default a surface still tolerates what streaming leaves incomplete.
- Strict validation also holds every message to its version's schema, the A2UI specification's own (v0.9, v0.9.1 and v1.0, shipped with the gem with the basic catalogs), with the surface's catalogs plugged in: an unknown component or property, a mistyped value, a malformed call or its arguments, or a v0.9 theme the catalog's theme refuses is a `VALIDATION_FAILED` worded "Validation failed for component 'Button' (id): ..." or "Validation failed for theme on surface 's1': ...". On v1.0 a component or call that names its own catalog is checked against that catalog. The schemas run through a dependency-free JSON Schema 2020-12 interpreter (`A2UI::Schema`); a catalog binding hands strict validation its document through `#document` (Basic, Native), and a binding without one admits anything.
- A v1.0 `createSurface`'s `metadata` holds only `extensions`, whose keys are identifiers, in any mode.
- `Session#status`: the lifecycle status AG-UI's A2UI middleware sends while the agent builds a surface (`{ "status" => "building", "progressTokens" => 20 }`).
- A component's accessibility `description`, `live` and `hidden` reach its element as `aria-description`, `aria-live` and `aria-hidden`, beside the label.
- poetry-agent's tests run A2UI's 17 renderer conformance suites (vendored under `test/fixtures/a2ui/upstream` with `rake a2ui:vendor` and `rake a2ui:verify`) and render all 87 of the basic catalogs' v0.9 and v1.0 examples.
- `describe_component` prints one line per behavior the component uses.
- The AG-UI `Transcript`'s text and reasoning parts carry `state:`: `:streaming` until their END event (or a `RUN_ERROR` ending the run mid-message) closes them, then `:done`; a `MESSAGES_SNAPSHOT`'s parts arrive `:done`. Closing a part re-renders its row through the relay, so a reasoning step reads "Thinking" while it streams and "Thought" once it closes.
- `Poetry::Agent::AGUI::Pipeline`, AG-UI 1.0's processing model in the order the protocol fixes: the compatibility boundary (retired `THINKING_*` events become `REASONING_*`, a `null` in a whole optional field reads as absent, legacy `binary` content parts become media parts, each with a warning), your `middleware:`, enforcement against a contract table generated from the 1.0 schema (anything the protocol does not describe is stripped with a warning; a malformed known field fails the run), chunk expansion (`*_CHUNK` events become their start, content and end form, per subagent lane), and verification (the run lifecycle and every message, tool call, reasoning span, step and subagent opened before it continues and closed before `RUN_FINISHED`). It passes AG-UI's 388 reference vectors, all 67 receiver conformance streams a third-party client is scored on, all six era streams, and 60 captures from real producers with no rejection and no warning.
- `ProtocolError` (`stage`, `kind`, and the `events` the failing push delivered before it) and `ProtocolWarning` (`kind`, `message`). Warnings are never silent: `Pipeline.new(on_warning:)` receives each, and `pipeline.warnings` keeps them.
- `Pipeline.new(mode: :lenient)` for developing against an agent that is not conformant yet: it drops the offending event with a warning instead of failing, admits a well-formed run boundary over what the run left open, reads snake_case keys as their camelCase fields with a warning, and never runs a damaged call (a tool call that lost an event never finishes, so a frontend tool never sees half its arguments).
- `Pipeline.new(max_protocol_version:)` for an agent known to speak an older version: "0.0.57" strips subagent material both ways and "0.0.39" also sends content as plain text, each loss named in a warning, and the input leaves out `protocolVersion` for an agent that predates it. `Pipeline#outgoing(input)` prepares a run input for the agent and enforces it, so a malformed field fails before anything is sent.
- `RunInput.build(interrupts:)` holds a resume list to AG-UI 1.0's rules before anything is sent: every open interrupt needs an entry (omission is not cancellation), and one whose `expiresAt` has passed can only be cancelled; either mistake raises `ProtocolError`. `RunInput.expired?` reads an interrupt's expiry.
- The pipeline names an interrupt signalled the pre-1.0 way, a `CUSTOM` `on_interrupt` event on a run that then finishes without the interrupt outcome, with the setting that fixes it.
- The AG-UI run input declares the protocol version it speaks, `protocolVersion: "1.0"` (`Poetry::Agent::AGUI::PROTOCOL_VERSION`), as AG-UI 1.0 requires; `RunInput.build(protocol_version: nil)` omits it for an agent known to predate the field.
- `Transcript#runs` keeps every run on the stream, so a first run's failure survives a second run.
- `Transcript#add_message` records a message the host sends (the user's turn, a tool result, a system prompt), so `messages_for_input` carries the whole conversation: no event echoes the user's own turn, and a stateless agent never saw it again.
- `Relay` takes a row a snapshot renamed or dropped off the page (a remove stream; `remove_targets:` names what to remove, such as the scroller item around the row), so a message no longer shows twice. `TurboStream.remove_all(selector)` builds the stream.
- User and tool messages carry content parts (text, image, audio, video, document) end to end: `RunInput.user_message` and `tool_message` take a list of parts, a snapshot's parts arrive as text and `:media` parts, and `messages_for_input` sends them back as parts.
- AG-UI 1.0 metadata: each event's `metadata` merges into what it builds, key by key with the last write winning (a message's `Message#metadata`, a tool call part's `metadata`, a tool result, an activity), and `messages_for_input` returns it, as it returns `name`.
- Subagents: a message carries the `subagentRunId` of the invocation that built it (`Message#subagent_run_id`), and `Transcript#subagents` / `#subagent(id)` record each announced invocation's name, parent, status (`:running`, `:finished`, `:suspended`, `:error`), outcome and result.
- Encrypted reasoning (`REASONING_ENCRYPTED_VALUE`) is stored with the message or tool call it names, kept out of the parts, and returned unmodified in `messages_for_input` to the producer that issued it; one naming nothing the transcript holds is dropped with a warning.
- A run records its `usage` and `pending_tool_call_ids` (the producer's list, or the calls the run started that no result answered); a cancelled run keeps no result and waits for nothing.
- `Transcript#truncate` and `#truncated?` for a run the host stopped reading (it broke out of `client.run`, or the stream died under it): the run reads `:truncated`, nothing is invented for it, and what still streamed closes. `Relay#finish` truncates a run its stream broke off in and answers the streams that re-render it.
- `Transcript#state=` seeds the state the host sends with a run, so the agent's first `STATE_DELTA` patches what it was sent, and a `RUN_STARTED` that echoes its input adds the messages the transcript lacks.
- A frontend tool can ask the user first: `Transcript.new(client_tools: [{ name: "book", confirm: true }])` marks its pending call `confirm: true`, `Relay#client_tool_streams(approval:)` renders the host's prompt inside the bridge element, and the bridge runs the call on Approve or posts `declined: true` on Deny. `Transcript#decline_client_tool` answers a declined call (its part reads `:denied`); the agent is told it was declined, never that it ran.

### Changed

- The MCP server runs on the official `mcp` gem: the gem speaks JSON-RPC 2.0, negotiates the protocol version (the latest it knows, or the older one a client asks for), validates every call's arguments against the tool's schema (a value off an enum answers as a tool error before the tool runs) and answers a raising tool with its internal error. `Server#handle` and `#serve` keep their signatures; `Server#mcp` is the gem's server underneath, open to a host's own tools and resources. `compose` and `build_page` mark nothing required, so a blank brief still gets their guidance.
- `Poetry::Agent::MCP::HTTP` is the gem's Streamable HTTP transport in its stateless JSON mode: one POST, one JSON reply, no session and no event stream. Batches are refused, as the protocol dropped them; a client sends `Accept: application/json` (a browser's `*/*` passes); the Origin check stays Poetry's, with `allowed_origins:` for other origins; the Host header stays the host application's to validate.
- The A2UI surface controller waits for the user before it tells them of a failure: an input's message and invalid state appear once they have edited it, a button's reason once they have edited any input (a button whose checks fail is still disabled from the start); until then the server's rendering stands, including the failures it rendered after a rejected action, and a failure on a function the browser cannot judge stands until the server judges it again. The check program's entries carry the path each control binds, and the surface form's actions are `touch` and `morphed`.
- A CheckBox's label is visible, beside the box in a Field's boolean-control row and paired by `for`, and a ChoicePicker's checkboxes carry their labels the same way; both were an `aria-label` only.
- BREAKING: every A2UI message must name its version (`"Missing required version field"` otherwise), as both versions' schemas require. v1.0's wire version is the bare `"1.0"`; its earlier spelling `"v1.0"`, which today's published agent SDKs still send, is accepted on input. Poetry sends `"1.0"` (or `"v0.9"` on a v0.9 surface), never `"v1.0"`.
- BREAKING: on a v1.0 surface a binding is `{ "@path" }` and a call `{ "@call" }`, as v1.0 specifies; `{ "path" }` and `{ "call" }` are literal objects there. Payloads written with the old keys under a v1.0 version move to `@path` and `@call`, or declare `"v0.9"`.
- The browser's check program is spelled as v1.0 spells it whatever the surface speaks, and carries the surface's version; a resolved value's plain objects and lists resolve what they hold.
- An action's `userMessage` is resolved (a binding or a call) and sent when it is not empty.
- A2UI's basic functions answer as the surface's version does: v0.9's validators return booleans and an object reads as true in `and`, `or` and `not`; v1.0's return a ValidationResult, which reads as its verdict in any boolean argument (`formatNumber`'s `grouping` among them), and `email`'s refusal carries `INVALID_EMAIL` and its message. A check's message is its result's, the rule's the fallback, so a v1.0 email check now shows `email`'s message over the rule's; a failure reports a severity only when its result names one. The browser's copy answers the same way.
- `required` counts an object as present, `length` counts a list's items, `email` wants a top-level domain of two letters or more, `and` and `or` need two values, `formatDate` takes the pattern `"ISO"` and returns `""` for a date that does not exist (`2026-02-30`), and `openUrl` answers nothing (the renderer links to the URL) and also opens `mailto:` and `tel:`.
- Poetry's v1.0 catalog document passes A2UI's current catalog meta-schema: function entries are flat `{ "@call", "args" }` schemas with `returnType`, `allowedCallers` and `requiresUserActivation` beside them, common types are referenced relative to the catalog (`common_types.json#/$defs/...`), and a component that needs content says so in its description instead of a root `anyOf`, which the meta-schema refuses (the renderer still requires the content).
- BREAKING: A2UI catalogs resolve as v1.0 specifies, with no fallback. A `createSurface` naming a catalog the session does not hold, or one built for another protocol version, is refused (`CATALOG_ERROR`); `Session.new(fallback_catalog:)` binds such ids to a catalog of the host's choosing (the former `default_catalog:`, which fell back by default, is gone). On a v1.0 surface a component and a function call may name their own catalog (`catalogId`) among the session's catalogs of the surface's version, a call nested in another's arguments resolving its own; one that names none uses the surface's default, which a v1.0 surface may omit, and a component or call that cannot be resolved is refused when it arrives. `Surface#catalog_of`, `#lookup` and `#catalog_problem` answer what resolves where; v0.9 keeps one catalog per surface.
- BREAKING: an agent's `callRendererFunction` is answered as v1.0 specifies: always with a `rendererFunctionResponse`, carrying the value or an `error` (`INVALID_FUNCTION_CALL` for a call the renderer refuses, `EXECUTION_ERROR` for one that raises), where Poetry used to send a top-level error. The call must name its `catalogId`, with no fallback to a default catalog; a catalog built for another protocol version, an undeclared function, an argument of the wrong declared type and a function that needs a user's gesture are refused. `Session#apply(message, user_activated: true)` says the message answers the user's gesture, so a function like `openUrl` may run.
- The `formatString` grammar follows the spec: its numbers (a sign, `.5`, `5.`, exponents, the double range), path characters, string escapes, a trailing comma after the last argument, `null` as the empty string, nesting up to 100, and its error wording; a positional argument (`upper(x)`) is an error.
- A function that needs a user's gesture (`openUrl`) runs only from one, a button's action; in a passive binding or a check it fails, as the spec says.
- On a v0.9 surface, the v0.9 docs' shorthand forms are read with a warning: an action written as `{ "name", "context" }` without `event`, and a check rule written flat (`{ "call", "args", "message" }`) without `condition`. `Surface` is a reserved component name in v1.0 only.
- One A2UI message that names a component id twice is refused (`INTEGRITY_ERROR`), and a circular reference is a `RECURSION_ERROR` worded as the spec words it.
- A2UI errors use the spec's wording (`Surface s1 already exists.`, `Surface not found for message: s1`, `Unsupported protocol version 'v99.0'`, `Message contains multiple conflicting update actions`, `Self-reference detected`), and a `deleteSurface` for a surface that does not exist is a no-op, as the spec says.
- A2UI data model writes follow the spec: a missing step before an index becomes a list, a removed list element keeps its slot as null, an index has no leading zero, a primitive root is kept, and a write through a primitive, a name on a list, or a forbidden segment (`__proto__`, `constructor`, `prototype`) is a `DATA_ERROR` that changes nothing. A relative path takes `.` and a scope with a trailing slash.
- The released gem serves its JavaScript minified, as poetry-core does, from `dist/javascript` with a source map beside each file.
- The MCP check tool warns on a renamed Lucide icon with its current name instead of rejecting it.
- BREAKING: `RunInput.resume_entry` requires `status:` and takes only AG-UI 1.0's two, `"resolved"` (the answer in the payload) and `"cancelled"`, raising `ArgumentError` otherwise. The former `"approved"` / `"rejected"` are rejected by 1.0 agents.
- A reasoning message is a message of its own (role `reasoning`), as in AG-UI 1.0, and travels back in `messages_for_input`, as do system and developer messages; only activity messages stay behind.
- A tool call without a `parentMessageId` gets an assistant message of its own under the call's id, as the reference client does, instead of joining whichever message came last.
- A `MESSAGES_SNAPSHOT` reconciles by id, as AG-UI 1.0 specifies, instead of replacing everything: a message it carries replaces the copy with the same id in place, one never seen is appended, and one it leaves out is dropped, except activity and reasoning messages, which a snapshot carrying none of that role keeps. Streamed reasoning used to vanish at a closing snapshot.
- A run that finishes with the cancelled outcome reads `:cancelled`, neither success nor failure; `ended?` counts it.
- A tool call's arguments go back to the agent exactly as they streamed (an argument-less call sends `""`), and a tool result's message keeps the result's own `messageId` and its content parts.
- BREAKING: `Transcript#apply` takes only the verified events a pipeline delivers and raises `ArgumentError`, naming the pipeline, for a chunk, a retired `THINKING_*` event or an unknown type. It no longer reads snake_case keys. `unknown_events` is gone: a patch that does not apply, or an activity delta naming no activity, is a `ProtocolWarning` in `Transcript#warnings` (and `Transcript.new(on_warning:)`), as AG-UI 1.0 requires a failed patch to be surfaced.
- BREAKING: `Client#run(input, pipeline:)` yields verified events and returns the pipeline (`warnings`, `truncated?`) instead of the SSE parser. A frame that is not a JSON object fails the run with `ProtocolError` (stage `:transport`) instead of being listed and skipped, and the input is enforced before it is sent.
- `Relay#apply` runs raw events through a strict pipeline of its own; `Relay.new(pipeline: nil)` takes events `Client#run` already verified, and `Relay#finish` closes the stream. When a push fails, the client and the relay hand on what it delivered before the failure, then raise.
- A tool result is a message of its own in the transcript, as AG-UI 1.0 models it, instead of a field on its call: the call's part still reads the answer (`output`, `state`), `messages` still leaves results out, and `messages_for_input` sends each result right after the call it answers, as providers require.
- A string outside a closed set (a message `role`, an encrypted value's `subtype`) is stripped with a warning, as AG-UI 1.0's processing model requires, instead of failing the run; in a required position the event or entry carrying it is dropped. A value of the wrong type is still fatal.
- `Transcript#run[:result]` holds a successful run's result only.

### Fixed

- Poetry's A2UI catalog advertises `children` on exactly the components that render their block, read from the registry's `content` fact: 15 that do (Field, Alert, Toast, Tree, Label, Fieldset, Toggle...) had none, so an agent could not give a Field its control and strict validation refused one that did, and 13 that fill from slots alone (Tabs, Accordion, Select, Sidebar, Pagination...) had it anyway. A registry without the fact reads as before.
- The surface controller evaluates the checks again when a streamed re-render morphs the surface (`turbo:morph-element`) or changes its program; a button's state and an input's message could stay stale until the next keystroke.
- A single-select ChoicePicker's chips lay out as a wrapping row of pills, as the multi-select's do; only the arrow keys' axis had changed. The `a2ui-chips` rules ship in `poetry-agent.css`, so a host copies the file again (`poetry:install`) to pick them up.
- A v1.0 form using `@path` and `@call` works: its inputs were never bound to the data model, so a submit carried nothing, and its checks always failed in the browser, so its button never enabled.
- AG-UI's A2UI middleware renders end to end: its status-only activities while the agent builds a surface were rejected as messages without a version, and its replacing snapshot, which carries every operation so far, failed on its repeated `createSurface`.
- A ChoicePicker without a label renders, its accessible name taken from its accessibility label or its id; Poetry's radio group refused it and it vanished.
- An A2UI agent can no longer make the data model allocate an array of any size: a write names an array index up to 10,000 (A2UI's bound) or `-` to append, and anything else on an array (`/items/999999999`, `-5`, a name) is refused with a `DATA_ERROR` message on the surface instead of growing the array or raising `IndexError`. An input bound to such a path is skipped on submit with the same error.
- An A2UI function that raises no longer escapes: from `callRendererFunction` it answers `EXECUTION_ERROR` with the function's name and the exception's class (not its message), and during a render the call fails with a warning while the surface still renders.
- `formatNumber` and `formatCurrency` hold `decimals` to 0 through 100, so an argument can no longer ask for a string of any length; a negative count no longer raises.
- An `ACTIVITY_DELTA` after a `MESSAGES_SNAPSHOT` no longer raises `NoMethodError`: a snapshot carrying no activity keeps the activities, so the delta applies; one naming an activity no message holds is skipped with a warning.
- A frontend tool called through `TOOL_CALL_CHUNK` events waits on the browser once the run ends; it used to stay loading and never reach the bridge.
- A snapshot's multimodal user content is kept as parts instead of becoming a Ruby `inspect` string.
- A `null` state snapshot applies (state may be any JSON value), and a closed tool call reopened with the same id appends its arguments instead of minting a second call. Arguments arriving for a closed call are ignored instead of raising, and a `TOOL_CALL_CHUNK` continuing a call a snapshot restated reopens it.
- A client tool waiting on the browser keeps waiting through a `MESSAGES_SNAPSHOT` (it showed loading again), and follows its call when the snapshot renames the message.
- A `RUN_ERROR` in the middle of a frontend tool call no longer hands the call to the browser with half its arguments: a call whose arguments never closed is abandoned, never run.
- Arguments that stream after a `MESSAGES_SNAPSHOT` restated a call still open reach the call the page shows; they used to land on a copy the snapshot had replaced.
- Tool results no longer go missing: a result a snapshot lists before its call answers that call, one whose call is not held is kept and sent back, and a second result for one call no longer replaces the first. After a reload the agent used to receive a call with no answer.
- A tool result's `error` no longer overwrites its `content` in the next run's input; both travel.
- A `parentMessageId` naming a tool result gives the call an assistant message of its own (with a warning) instead of sending two messages with one id; text aimed at an activity or a tool result's id is refused with a warning instead of corrupting it; a renamed reopened call is named in a warning.
- An activity a host added with `add_message` is registered, so `ACTIVITY_SNAPSHOT replace: false` keeps it and a later `ACTIVITY_DELTA` applies; a held assistant message with empty `content` keeps it; `add_message` skips a `null` tool call instead of raising.

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
