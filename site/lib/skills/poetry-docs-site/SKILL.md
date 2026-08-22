---
name: poetry-docs-site
description: Navigate the poetry documentation site as an agent - where the machine-readable catalog, markdown mirrors, registry, and skills live, and how to install components from here.
---

# Using the poetry docs site

## Summary

This site documents poetry, an AI-native, Rails-first component library. Every surface below is machine-readable; prefer them over scraping HTML.

## Discovery

- `/llms.txt` - the site index: every page with a one-line description.
- `/poetry/llms.txt` - the component catalog for agents; `/poetry/llms-full.txt` adds full contracts and Stimulus wiring (targets / values / actions / events).
- Every docs page serves a markdown mirror: append `.md` to its URL, or send `Accept: text/markdown`.
- `/installation.md` - copy-and-follow install instructions for a coding agent.

## Registry

- Index: `/r/registry.json` (shadcn-schema items; directory of registries at `/r/registries.json`).
- Install into a Rails app with poetry installed: `bin/rails g poetry:add <name>`.
- Or with the shadcn CLI: register the namespace in components.json (`"@poetry": "<this site>/r/{name}.json"`), then `npx shadcn add @poetry/<name>`.

## Skills

- `/.well-known/skills/index.json` lists the installable skills with file rosters; fetch files at `/.well-known/skills/<name>/<path>`.
- `/.well-known/agent-skills/index.json` is the discovery index (agentskills.io schema 0.2.0): each entry carries a payload `url` and `sha256:` digest, so `npx skills add <this site's url>` installs from here.
- In a Rails app, `bin/rails g poetry:skill` installs the same skills locally.

## Working in an app that has poetry

- Compose with `poetry_*` helpers; never hand-write `cn-*` classes or raw colors.
- Run `bin/rails poetry:check` as the FINAL action after edits - it verifies components, slots, variants, and wiring.
- The poetry MCP server (`bundle exec poetry-agent`) serves compose/check/describe tools with no app boot; `bin/rails g poetry:editor` wires it into editors.
