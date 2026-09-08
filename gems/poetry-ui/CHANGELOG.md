# Changelog

## [Unreleased]

### Changed

- HoverCard's trigger wiring is `pointerdown->pointerDown` (was `touchstart->touchGuard`), and NumberField's input no longer wires a `focus` action. A copy made with `poetry:add hover_card` or `poetry:add number_field` before this version carries the old wiring and logs a Stimulus "undefined method" error on those events: run `bin/rails g poetry:diff` and update the two lines. Apps on the gem-owned tier need nothing.

## [0.1.0] - 2026-09-05

Initial public release. The family releases in lockstep; every gem pins its siblings at the same version.

- Eighty-eight server-rendered components, the shadcn/ui set as ViewComponents on Stimulus, with nine complete visual themes and eight whole-screen blocks.
- The model-bound form builder deriving labels, hints, errors, and aria from the model; testing helpers that drive components the way a user would.
- Chat and streaming components (message, bubble, marker, attachment, message scroller) and the deterministic `Poetry::Ui::Chat` replay rig.
- Generators: `poetry:install`, `poetry:add`, `poetry:block`, `poetry:skill`, `poetry:agents`, `poetry:agent_rules`, `poetry:editor`, `poetry:scaffold_templates`, `poetry:pagination`, `poetry:diff`, and the screen recipes.
- The engine serves llms.txt and llms-full.txt; Tabs, Dialog, Sheet, Drawer, and Combobox declare WebMCP tools.
