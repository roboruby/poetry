# Changelog

## [0.1.12] - 2026-10-07

### Added

- The poetryui.com documentation as a mountable engine, `Poetry::Docs`, moved from the repository's `site/` app with its guides, galleries, demos and machine surfaces intact: its own layouts, a prebuilt stylesheet with the nine-theme registry, its own importmap entry point and Stimulus application, and file reads that resolve against the engine's root. A host mounts it at the root of its docs hostname and takes it from the repository at a release tag; the engine is versioned with the family and not published. The dummy host under `test/dummy` serves it for authoring and the tests.
- A Jumpstart Pro library page, `/libraries/jumpstart-pro`, the guide to poetry-jumpstart_pro from install to removal, with its Markdown mirror; the Installation guide's "Installing into a Jumpstart Pro app", the Pagination guide's Jumpstart Pro setup, and a Jumpstart Pro section in the agent install instructions.

### Fixed

- The pagination guide renders in any host. The engine requires the guide's paginators itself (pagy, kaminari's core and Action View parts, will_paginate's collection, never their Active Record extensions), where before only the dummy host did, so a host that only mounts the engine raised `NameError` on `/pagination`.

