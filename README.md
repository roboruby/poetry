# poetry

An AI-native, Rails-first component library — a shadcn/ui-parity design system built on ViewComponent, Hotwire, and Tailwind, designed so coding agents compose UI inside a constrained design system.

Documentation, live component previews, and guides are at [poetryui.com](https://poetryui.com).

This is the umbrella gem. One line installs the library proper: the engine, the components, and the default icon set. Everything else in the ecosystem is opt-in and listed below.

## What the umbrella installs

### [poetry-core](https://github.com/roboruby/poetry-core) — the engine and the component DSL

The framework layer every other gem builds on. It ships the Rails engine, the `Component` base class, and the DSL that gives a component its vocabulary: style axes with variants, typed options, named parts, and slots, each of which projects into the machine-readable registry. The Stimulus integration lives here too, with the `use_stimulus` declarations that wire controllers, targets, values, and actions from Ruby, plus the vendored positioning engine the overlays share.

Core also owns the design-token foundation: the semantic token set, the Tailwind theme layer built from it, and the `DESIGN.md` interop that lets a theme round-trip as a document. The preview and testing infrastructure, the registry builder, and the agent-text generators (the `llms.txt` projection and the installable skills) are shared here so every gem in the family speaks with one voice.

### [poetry-ui](https://github.com/roboruby/poetry-ui) — the components

The component library itself: 88 components covering forms, overlays, data display, feedback, navigation, chat, and layout, built entirely on poetry-core's public DSL and exposed to views as `poetry_*` helpers. Every component is accessible by construction, themeable through the token layer, and legible to agents through the registry that the helpers, the docs, and the MCP tools all read.

Beyond components it carries nine complete visual themes, a model-bound form builder that derives labels, hints, errors, and aria from the model (`form_with(model:, builder: Poetry::Ui::FormBuilder)`), eight vetted blocks for whole screens (app shell, top nav, page header, data index, section card, stepper, action bar, destructive panel), and the agent surface: the `poetry:install` generator that writes the Claude Code skills, `bin/rails poetry:check` for verifying composed markup, and the registry served for `poetry:add`.

### [poetry-lucide](https://github.com/roboruby/poetry-lucide) — the default icon set

Lucide's 1,745 icons, vendored at a pinned upstream commit and sanitized at vendor time, so rendering an icon never parses SVG, never sanitizes, and never touches the network. The set registers with poetry-core's icon registry, which is what `poetry_icon(:"circle-check")` and every icon-bearing component resolve against. A wrong name raises in development with a did-you-mean suggestion, `bin/rails poetry:check` catches literal names before that, and in production a configured fallback glyph renders instead of a 500.

## Installation

```ruby
# Gemfile
gem "poetry"
```

```bash
bundle install
bin/rails generate poetry:install
```

The generator wires the engine, the Tailwind entry point, and the importmap pins, and writes the agent skills into `.claude/skills/`. From there, `poetry_button`, `poetry_dialog`, `poetry_data_table` and the rest are available in every view.

## Additional ecosystem gems

Add what you use; nothing here is pulled in by the umbrella. The family releases in lockstep, and every gem pins its siblings to its own version, so add these without version constraints and Bundler resolves them to the umbrella's release.

### [poetry-charts](https://github.com/roboruby/poetry-charts) — server-rendered SVG charts

Eight chart types (area, bar, line, pie, radar, radial bar, scatter, composed) whose geometry is computed in Ruby: data to domains to scales to ticks to points to paths, with d3-scale and d3-shape semantics and recharts' nice ticks. The finished chart ships in the initial HTML, so it is valid with JavaScript disabled, in print, in PDFs, and in email, and it is themed by CSS variables so dark mode flips without a re-render.

A small Stimulus layer adds tooltips, legends, and active states by reading coordinates the server embedded, with zero client-side chart math. Engines stay swappable behind a closed, versioned chart spec, with a Chart.js adapter as the reference. Install with `bin/rails generate poetry:install --charts`.

```ruby
gem "poetry-charts"
```

### [poetry-agent](https://github.com/roboruby/poetry-agent) — the agent surfaces

Every surface through which an agent reaches the component contract, projected from the same registry the other gems build. Five ship: the boot-free `poetry-agent` MCP server for coding agents (`compose`, `build_page`, `describe_component`, `check`, `get_skill`, and friends over stdio, with an HTTP mount for hosted agents); the WebMCP runtime, which registers a rendered component's declared tools with the browser's agent when a call opts in; the AG-UI relay, a Rails client of the Agent-User Interaction protocol that runs an agent and renders its events as Turbo Streams; the A2UI catalog, which projects the registry into an A2UI catalog document; and the A2UI renderer, which folds an agent's surface messages into rendered Poetry components.

Loading the gem is the integration: it registers its controllers with poetry-core, pins its JavaScript, and adds the origin-trial middleware, which stays inert until tokens are configured. Its only runtime dependency is poetry-core.

```ruby
gem "poetry-agent"
```

### [poetry-extract](https://github.com/roboruby/poetry-extract) — domain in, theme out

Point it at a public website and get back a `DESIGN.md` document plus deterministic design tokens, ready for Poetry's AA-gated theme importer. It fetches the site's styleguide, brand, screenshot, and homepage markdown, composes the `DESIGN.md` in one Claude call, derives a Tailwind v4 theme and CSS `:root` tokens deterministically from it, and hands the result to the importer that refuses any theme failing the contrast gate.

```ruby
gem "poetry-extract"
```

```bash
bin/rails "poetry:design:extract[stripe.com]"
```

### [poetry-simple_form](https://github.com/roboruby/poetry-simple_form) — the migration bridge

For apps already on simple_form. One initializer re-maps every simple_form input type onto classes that render whole Poetry fields through the form builder, so existing `f.input` and `f.association` calls keep working, now with label, hint, error, and aria derived from the model exactly as the native builder does. The controls simple_form never had are one `as:` away, `simple_form.*` i18n keys keep resolving, and removing the initializer restores stock rendering instantly. The bridge exists so views can migrate to the native builder at their own pace.

```ruby
gem "poetry-simple_form"
```

```bash
bin/rails generate poetry:simple_form:install
```

## Demo

### [Poetry in Motion](https://github.com/roboruby/poetry_in_motion) — generative UI on Rails

A Rails app whose screens are composed while you talk. You ask an operations analyst about a synthetic bank (50,000 customers, a million transactions) and the analyst answers through [RubyLLM](https://rubyllm.com) by building the workspace around the conversation out of Poetry components: KPI rows, tables, charts, customer cards, filter forms, and buttons that ask the next question for you. Surfaces talk back, so a button or a filter inside one becomes the next turn, and follow-ups update the surface in place rather than adding a duplicate.

It is the reference implementation for Poetry's RubyLLM installer, what `rails g ruby_llm:chat_ui` scaffolds rebuilt on Poetry's chat components, and it runs the umbrella together with poetry-charts and poetry-agent, so it is the quickest way to see the library, the charts, and the agent surfaces working in one app. Clone it, add an OpenRouter key, and `bin/setup` imports the bundled dataset in about thirty seconds.

## Status

Early release. The API is settling but not frozen; breaking changes are called out in the CHANGELOG from 0.1.0.

## License

Available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
