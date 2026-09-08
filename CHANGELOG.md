# Changelog

## [0.1.1] - 2026-09-08

### Changed

- README: the docs site linked in the opening, and a Demo section for Poetry in Motion. Lockstep release with the family.

## [0.1.0] - 2026-09-05

Initial public release. The family releases in lockstep; every gem pins its siblings at the same version.

- The umbrella gem: `bundle add poetry` then `bin/rails g poetry:install` brings the engine (poetry-core), the components (poetry-ui), and the default icon set (poetry-lucide) at one version.
- Charts, theme extraction, the agent surfaces, and the simple_form bridge stay opt-in gems on the same version.
