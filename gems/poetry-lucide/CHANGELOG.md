# Changelog

## [0.2.0]

### Changed

- Lucide 1.57.0, from 1.23.0: 1,890 icons, with 160 new, 96 redrawn and 15 renamed. The renamed names, `trash-2` among them, render through aliases.

### Added

- `icons/aliases.json` and `Poetry::Lucide.aliases`: the 264 names Lucide has renamed, each mapped to its current name, read from the icons' own metadata at vendor time. An old name keeps rendering after an update, and `poetry check` warns with the new one. The fetch now also removes icons the upstream dropped.
- `icons/tags.json` and `Poetry::Lucide.tags`: the words Lucide files each of the 1,890 icons under (`trash` under delete, garbage and remove), read from the icons' own metadata at vendor time. The set hands them to `Poetry::Core::Icons.find`, so an icon can be asked for by what it means.
- An unknown name that looks like a brand is pointed at the brand set: Lucide draws no brand marks, and the error for `:github` now says they are in poetry-simple_icons, as `poetry_icon(name: :github, library: :simple_icons)`.

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

- The gem is developed in the Poetry monorepo, roboruby/poetry, under `gems/poetry-lucide`; the gemspec's source, changelog and issue links point there, and its file list no longer needs git on the machine (a path gem inside a slim image lists the same files).

## [0.1.5] - 2026-09-18

Lockstep release with the family; no changes in this gem.

## [0.1.4] - 2026-09-15

Lockstep release with the family; no changes in this gem.

## [0.1.3] - 2026-09-13

Lockstep release with the family; no changes in this gem.

## [0.1.2] - 2026-09-13

Lockstep release with the family; no changes in this gem.

## [0.1.1] - 2026-09-08

Lockstep release with the family; no changes in this gem.

## [0.1.0] - 2026-09-05

Initial public release. The family releases in lockstep; every gem pins its siblings at the same version.

- Lucide's 1,745 icons as the default poetry icon set, rendered through `poetry_icon` with validated names.
- Render time never parses, sanitizes, or fetches; the icon is a compiled SVG.
