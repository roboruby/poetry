# Changelog

## [0.1.1]

### Changed

- `poetry--core--hover-card`: `touchGuard` (on touchstart) is replaced by `pointerDown` (on pointerdown). `poetry--core--number-field`: the `focus` action is removed. A host that wired either by hand updates the action strings; poetry-ui's components already have.

## [0.1.0] - 2026-09-05

Initial public release. The family releases in lockstep; every gem pins its siblings at the same version.

- The component framework on ViewComponent: the `Component` base class with the options, slots, variants, states, and parts DSL, class merging, HTML attribute handling, and the Stimulus wiring builders every component runs through.
- Design tokens authored once and compiled to a Tailwind v4 theme or BEM CSS behind a contrast gate, with nine visual themes.
- The component registry that every other surface projects from: `poetry check` verification of Herb-parsed ERB, llms.txt generation, registry items in the shadcn registry format, and stable ids for Turbo morphs and fragment caches.
- Shared Stimulus controllers (`@poetry/core`), the preview infrastructure, the agent tools DSL for WebMCP declarations, and the install-time class safelist.
