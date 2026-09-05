# Changelog

## [Unreleased]

## [0.1.0] - 2026-09-05

Initial public release. The family releases in lockstep; every gem pins its siblings at the same version.

- Nine chart families as server-rendered SVG: area, bar, line, composed, pie, radar, radial bar, scatter, and an adapter mount for client-side engines. Ruby computes the geometry from data to paths.
- The chart container, tooltip layer, tooltip content, and legend content components, with live re-rendering, zoom, and brush on the cartesian families.
- A `poetry_<name>` helper for every component, plus the `poetry_chart` dispatcher; the `@poetry/charts` Stimulus controllers.
