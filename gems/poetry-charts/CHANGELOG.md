# Changelog

## [0.1.5]

### Changed

- The registry carries the gem's internal namespaces (`internals`), so `poetry check` can warn a host that names one.
- 9 methods the reference already hid with `@api private` are Ruby-private now: each was called only by its own class or template, so the runtime enforces what the tag only stated. A host that reached one gets a NoMethodError instead of an internal that may change without notice. The tag remains on the internals the family shares between its gems and on whole internal classes.
- Every class, module and method carries a one-sentence description, private helpers included: `rake yard:coverage:all` measures the whole tree (a tag-only docstring counts as blank) and the committed floor now stands at zero.
- The container, legend, tooltip and tooltip layer roots ride the core default `root_attributes`, passing only their own markup up; the rendered attributes are unchanged apart from their order on the element.

## [0.1.4] - 2026-09-15

### Changed

- A horizontal bar chart's category strip fits its labels. The reserved left strip held about eight characters at the tick size, so a merchant name or a title was cut at the SVG edge. The strip now grows through the left margin to fit the longest formatted label (estimated by character count, capped at forty percent of the width), labels past the cap end in an ellipsis, and a live chart's recompute prints the same. An explicit `margin: { left: }` is the caller's layout and keeps the reserved strip.

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
