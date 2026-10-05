# Changelog

## [0.1.12]

### Added

- The poetryui.com documentation as a mountable engine, `Poetry::Docs`, moved from the repository's `site/` app with its guides, galleries, demos and machine surfaces intact: its own layouts, a prebuilt stylesheet with the nine-theme registry, its own importmap entry point and Stimulus application, and file reads that resolve against the engine's root. A host mounts it at the root of its docs hostname and takes it from the repository at a release tag; the engine is versioned with the family and not published. The dummy host under `test/dummy` serves it for authoring and the tests.
