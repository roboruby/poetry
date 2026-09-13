# Changelog

## [0.1.3] - 2026-09-13

Lockstep release with the family; no changes in this gem.

## [0.1.2] - 2026-09-13

### Changed

- The charts pin `css_mode :tailwind` for their namespace, like poetry-ui: a host's global `:bem` (for a kit of its own on the DSL) never reaches them.

## [0.1.1] - 2026-09-08

### Changed

- Theme headers reference the shadcn@4.21.0 pin; the chart rule is unchanged. Lockstep release with the family.

## [0.1.0] - 2026-09-05

Initial public release. The family releases in lockstep; every gem pins its siblings at the same version.

- Nine chart families as server-rendered SVG: area, bar, line, composed, pie, radar, radial bar, scatter, and an adapter mount for client-side engines. Ruby computes the geometry from data to paths.
- The chart container, tooltip layer, tooltip content, and legend content components, with live re-rendering, zoom, and brush on the cartesian families.
- A `poetry_<name>` helper for every component, plus the `poetry_chart` dispatcher; the `@poetry/charts` Stimulus controllers.
