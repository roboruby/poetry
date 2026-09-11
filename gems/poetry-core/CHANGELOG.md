# Changelog

## [0.1.2]

### Added

- `helper :name` on a component: an application's (or an engine's) own component written on the DSL names its view helper. The engine defines that helper on Action View at boot and on every reload, and `Poetry::Core::HostComponents` discovers the app's components by convention (under `app/`, outside the `poetry/` namespace, published), builds their registry live, and reads their declared helpers boot-free from source. The registry entry carries `helper`; `poetry check` lints a declared helper under its own name (options, variants, arity, stable identity); llms.txt and the generated skill take an app registry and render an App components section and a `references/app.md`.
- `css_mode` is decided per kit. A component class declares it (`css_mode :bem`, inherited), or a kit pins its namespace (`Poetry::Core::CSS::Modes.pin("Acme::Ui", :bem)`); the global `Config.current.css_mode` is the default for kits that declare nothing, and a `css_mode:` keyword on a `css` call still wins over all of them. poetry-ui and poetry-charts pin `:tailwind`, so a host's global never reaches them and a BEM kit on the DSL renders beside them in one app. Before, the global was the only switch and setting it to `:bem` silently stripped poetry-ui's styling.
- Registry roots by convention. `Poetry::Core::Registry.roots` (booted: every loaded engine whose root carries a published registry, then the app when it committed one), `.gem_roots` (boot-free, from the bundle, plus an app root), and `.merged` (one view over several roots, block templates resolved to absolute paths). A registry can mark itself `internal: true` and consumers skip it; poetry-core's own is now marked, since its building blocks have no helpers. `HostComponents.committed_state` reports the app's committed registry as missing, fresh, or stale against the live build.
- `Poetry::Core::CSS::TokenCollisions`: scans a host app's stylesheets for declarations of Poetry's token names (`--primary`, `--accent`, `--radius`, ...) and Tailwind theme keys (`--color-*`, `--radius-*`), and reports each with its location and what the role paints in Poetry's components. `poetry:install` and `poetry:check` run it.

### Changed

- The generated Tailwind theme mapping is `@theme inline default`. A host `@theme` value for the same key (its own `--color-primary`, a `--radius-sm` it set before Poetry arrived) wins whether it is declared before or after the mapping; Poetry's value still applies wherever the host set nothing. Before, the mapping replaced the host's keys wholesale, so every `rounded-sm` in an existing app changed size.

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
