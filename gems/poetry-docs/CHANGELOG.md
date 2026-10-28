# Changelog

## [0.1.14]

### Added

- The Islands library page: what an island is, the module contract, fill and flow with two live islands (a canvas clock and a counter that writes to its hidden input), the form seam, the Turbo lifecycle and the check, with its markdown mirror; the poetry-island and @poetry/island API pages.

- `config.community_registry` names a directory of community items: `/r/<name>.json` serves one when the gems ship no item of that name, and `/r/community/registry.json` serves their index. The UI library page explains the community fallback.
- A Motion section: one page per poetry-motion effect at `/motion/<slug>`, the Motion library guide (the payload, the motion policy, the tokens, the ten behaviors and when motion is just CSS), the poetry-motion API pages, and the effects in the sidebar, search and llms.txt.
- Component and chart pages show a Behaviors table beside Wiring: each behavior the component uses, where it is wired and what it does. The table says Poetry behaviors are not Herb's client behaviors.
- A page for each new icon set (Tabler, Hugeicons, Phosphor, Heroicons, Simple Icons) under /icons, with a live sample of every style, and the Lucide page updated for 1.57.0 and its aliases. The examples use `trash`, Lucide's current name for `trash-2`.
- Pages for poetry-solar and poetry-blode under /icons; an icon set with an attribution gets an Attribution section with its visible credit line.

### Changed

- The AG-UI Relay and Chat Replay demos render agent activity on Trace and CodeBlock, after shadcn's Trace chat example. Each run of reasoning and tool calls is one Trace: reasoning reads "Thinking", open, while it streams and "Thought" after; a tool call's words and status follow its state ("Looking up plans", "Looked up plans", waiting in the browser, failed); a finished call discloses its input and output in small CodeBlocks. An approval is an Item prompt with Deny and Approve, and a Chat Replay turn waits as a running "Thinking" line. The AG-UI Relay page's partial samples show the same mapping.
- The AG-UI Relay guide and its llms mirror speak AG-UI 1.0: the resume sample answers an interrupt with `status: "resolved"` and the decision in the payload (`cancelled` abandons it), user and tool messages take content parts, a reasoning message renders as its own row and travels back in `messages_for_input`, and `Transcript#runs` keeps every run.

### Fixed

- The AG-UI Relay demo's controls (the approval prompt, the replay link) follow the run's reply instead of sitting above it: each streamed message used to append after them.
- The AG-UI Relay demo's scripted agent emits conformant AG-UI 1.0: each `RUN_STARTED` declares `protocolVersion`, `REASONING_MESSAGE_START` carries its required `role: "reasoning"`, and the reasoning message has an id of its own instead of sharing the text message's. A 1.0 client rejected run one outright.

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

