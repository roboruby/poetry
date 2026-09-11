# Changelog

## [0.1.2]

### Added

- App components are first-class on the booted surfaces. A component the app defines on the DSL with `helper :name` renders through that helper, `poetry:check` lints it under that name with its own contract, `/poetry/llms.txt` and `llms-full.txt` list it under an App components section with its agent rules, and `poetry:skill` writes a `references/app.md` with a menu line. The MCP server's `check` tool learns the declared helpers from source, so it agrees the helper exists; its contracts and the runtime skill map stay gem-only (boot-free by design).

- `bin/rails poetry:registry` writes the app's own components to `config/component_registry.yml`, the path a gem's registry lives at, so the MCP server and the runtime skill find them boot-free with full contracts and agent rules. Opt-in; once written, `poetry:check` warns (`registry-stale`) and `poetry:verify` fails when the file no longer matches the classes.

### Changed

- `poetry:check` and the AGENTS.md census find registry roots by convention (every loaded engine with a published registry, then the app's own file) and name no gem; poetry-charts is no longer special-cased, and any engine built on the DSL that commits a registry joins the check the same way.
- `poetry:install` imports `tokens.css` into `layer(theme)`, so a token the host already declares (`--primary`, `--accent`, `--muted`, ...) keeps its value whatever the order in the Tailwind entry, and that value now reaches Poetry's components too. Before, the appended import landed after the host's own `:root` and took the same names over: an app's brand color vanished before a single Poetry component rendered. A re-run rewrites the earlier unlayered import line in place.
- `poetry:install` reports, before writing anything, every Poetry token name and theme key the app's stylesheets already declare, with the file and line and what Poetry paints with that role. It never blocks. `poetry:check` repeats the report as `token-collision` warnings.

### Fixed

- `poetry:install` no longer adds a second `herb` declaration when the gem is declared in a file the Gemfile pulls in with `eval_gemfile` (a shared Gemfile).

## [0.1.1] - 2026-09-08

### Added

- `content_class:` on `poetry_dropdown_menu` and `poetry_context_menu`, on Menubar's `with_menu`, and on every menu family's `with_sub`: the panel's class merge seam, the one Popover, HoverCard and Dialog already had. A dropdown panel opens at its trigger's width (minimum 8rem), so `content_class: "w-56"` is how a menu with icons, shortcuts or long labels gets its width.
- NavigationMenu `with_item(title, value:, disabled: true)`: an inert trigger (`disabled` + `data-disabled`) that hover, click and the arrows skip. `disabled:` on a link raises.
- `Poetry::Ui::Chat::Error`, a `Poetry::Core::Error`: `AssistantTurn#continuation_frames` raises it on a turn without an approval pause, where a missing constant raised NameError before.
- `poetry:install --skip-bundle`.

### Changed

- `poetry:install` adds the `herb` gem to the development group (once, never when the Gemfile already declares it) and runs `bundle install`, so `bin/rails poetry:check` works on a fresh app with no manual step. `poetry:check`'s missing-parser message points at the installer.
- The upstream pin is shadcn@4.21.0. The theme CSS is unchanged between the releases; both fidelity ledgers are re-snapshotted at the new pin.
- MessageScroller renders `data-pending-scroll` on its root and viewport for `:end` and `:"last-anchor"`; the viewport hides while it is set (visibility, so the layout stays) and the hold lifts without JavaScript. The part contracts declare the state.
- Select, Combobox and Command group headings are `aria-hidden`: the group's name flows through `aria-labelledby`, so screen readers stop announcing the heading a second time. Menu groups wire `aria-labelledby` to a label rendered inside them and hide it the same way; a label outside any group stays plain text.
- HoverCard's trigger wiring is `pointerdown->pointerDown` (was `touchstart->touchGuard`), and NumberField's input no longer wires a `focus` action. A copy made with `poetry:add hover_card` or `poetry:add number_field` before this version carries the old wiring and logs a Stimulus "undefined method" error on those events: run `bin/rails g poetry:diff` and update the two lines. Apps on the gem-owned tier need nothing.
- ToastTrigger names its Button root through `identity:`.
- NavigationMenu's agent rules state the keyboard contract: ArrowLeft/ArrowRight between triggers and links, ArrowDown opens the focused trigger's panel, Escape closes.

### Fixed

- HoverCard: a tap on the trigger clicks through on touch devices (the collapsed sidebar's icons did nothing on a tablet).
- NumberField: Tab's select-all and a click's caret placement stay native.

## [0.1.0] - 2026-09-05

Initial public release. The family releases in lockstep; every gem pins its siblings at the same version.

- Eighty-eight server-rendered components, the shadcn/ui set as ViewComponents on Stimulus, with nine complete visual themes and eight whole-screen blocks.
- The model-bound form builder deriving labels, hints, errors, and aria from the model; testing helpers that drive components the way a user would.
- Chat and streaming components (message, bubble, marker, attachment, message scroller) and the deterministic `Poetry::Ui::Chat` replay rig.
- Generators: `poetry:install`, `poetry:add`, `poetry:block`, `poetry:skill`, `poetry:agents`, `poetry:agent_rules`, `poetry:editor`, `poetry:scaffold_templates`, `poetry:pagination`, `poetry:diff`, and the screen recipes.
- The engine serves llms.txt and llms-full.txt; Tabs, Dialog, Sheet, Drawer, and Combobox declare WebMCP tools.
