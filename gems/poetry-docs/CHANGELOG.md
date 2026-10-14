# Changelog

## [0.1.14]

### Added

- `config.community_registry` names a directory of community items: `/r/<name>.json` serves one when the gems ship no item of that name, and `/r/community/registry.json` serves their index. The UI library page explains the community fallback.
- A Motion section: one page per poetry-motion effect at `/motion/<slug>`, the Motion library guide (the payload, the motion policy, the tokens, the ten behaviors and when motion is just CSS), the poetry-motion API pages, and the effects in the sidebar, search and llms.txt.
- Component and chart pages show a Behaviors table beside Wiring: each behavior the component uses, where it is wired and what it does. The table says Poetry behaviors are not Herb's client behaviors.

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

