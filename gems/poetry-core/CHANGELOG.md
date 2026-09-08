# Changelog

## [0.1.1] - 2026-09-08

### Added

- `identity:` on every component: the one sanctioned way for a component that renders as another component's root to name it (its `data-component`). Universal like `key:`, never an HTML attribute.
- `poetry check` rule `reserved-attribute`: `data-component` passed through a helper, as a string key or `data: { component: }`, is an error.

### Changed

- The passthrough contract is enforced at render. A keyword that is not an option still renders as an HTML attribute on the root, but a near miss of a declared option (`varient:`) raises in development and test with a did-you-mean and logs in production; `data-component` is never overridable (raised in development and test, dropped in production); `data-slot` stays open as a composition seam. `poetry check`'s `unknown-option` finding is an error, no longer a warning.
- `poetry--core--hover-card`: `touchGuard` (on touchstart) is replaced by `pointerDown` (on pointerdown). `poetry--core--number-field`: the `focus` action is removed. A host that wired either by hand updates the action strings; poetry-ui's components already have.
- `css_mode :bem` is documented as the mode for kits authored on the DSL that write their own templates; poetry-ui is Tailwind-native and not a `:bem` consumer.

### Fixed

- HoverCard: a tap on the trigger keeps its click on touch devices. The touchstart guard cancelled the click; a pointerdown latch held through the tap's compatibility mouse events replaces it.
- MessageScroller: `data-pending-scroll` holds the root and the viewport until the opening position (`end` or `last-anchor`) is applied, releases at once for an empty transcript, is stripped when a Turbo morph re-stamps it, and is re-armed at `turbo:before-cache`, so a server-rendered or restored transcript never shows the top of the thread first.
- NumberField: a sideways trackpad gesture over a wheel-enabled field scrolls the page instead of stepping, Shift on the horizontal axis steps large, and an event with no movement is neither stepped nor cancelled. Focus keeps the browser's own selection (Tab selects the value, a click places the caret); the steppers park the caret at the end.
- NavigationMenu: a disabled trigger never opens, by hover or click, and the arrows step over it; ArrowDown on a trigger opens its panel with focus staying on the trigger; removing the open trigger's item, as a morph can, closes the bar and drops its orphaned panel.
- Drawer: the click that follows a press inside the panel never dismisses, so a drag against the clamp released over the backdrop no longer closes the sheet.

## [0.1.0] - 2026-09-05

Initial public release. The family releases in lockstep; every gem pins its siblings at the same version.

- The component framework on ViewComponent: the `Component` base class with the options, slots, variants, states, and parts DSL, class merging, HTML attribute handling, and the Stimulus wiring builders every component runs through.
- Design tokens authored once and compiled to a Tailwind v4 theme or BEM CSS behind a contrast gate, with nine visual themes.
- The component registry that every other surface projects from: `poetry check` verification of Herb-parsed ERB, llms.txt generation, registry items in the shadcn registry format, and stable ids for Turbo morphs and fragment caches.
- Shared Stimulus controllers (`@poetry/core`), the preview infrastructure, the agent tools DSL for WebMCP declarations, and the install-time class safelist.
