# Changelog

## [Unreleased]

## [0.1.0] - 2026-09-05

Initial public release. The family releases in lockstep; every gem pins its siblings at the same version.

- An MCP server (stdio and HTTP) with ten tools read from the live registry: compose, build_page, list_components, describe_component, check, list_blocks, describe_block, list_recipes, get_skill, and guidance.
- The WebMCP runtime: Stimulus controllers that register component tools with the browser's agent, `poetry_webmcp_form`, a registration budget, and the origin trial middleware.
- An AG-UI client: SSE parsing, a transcript that folds events into messages, a relay that streams them as Poetry chat rows over Turbo Streams, and client tool bridging.
- A2UI on Rails: session, surface, and pointer model, the basic catalog and a native catalog for every registry component, checks and functions, the renderer, and Turbo Stream delivery with the versioned `vreplace` action.
- The `@poetry/agent` runtime registering all of it in one call.
