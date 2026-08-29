# poetry

An AI-native, Rails-first component library — a shadcn/ui-parity design system built on ViewComponent, Hotwire, and Tailwind, designed so coding agents compose UI inside a constrained design system.

This is the umbrella gem. One line installs the library proper:

- **poetry-core** — the Rails engine, the component DSL, the Stimulus integration
- **poetry-ui** — the components, the nine themes, the form builder, the agent surface
- **poetry-lucide** — the default icon set

## Installation

```ruby
# Gemfile
gem "poetry"
```

```bash
bundle install
bin/rails generate poetry:install
```

The generator wires the engine, the Tailwind entry point, and the importmap pins. From there, `poetry_button`, `poetry_dialog`, `poetry_form_for` and the rest are available in every view.

## Optional gems

Add what you use; nothing here is pulled in by the umbrella:

| Gem | What it adds |
| --- | --- |
| `poetry-charts` | Server-rendered SVG charts (area, bar, line, pie, radar, radial bar, scatter, composed) |
| `poetry-agent` | The MCP server and the WebMCP runtime |
| `poetry-extract` | Domain in, theme out: a DESIGN.md and design tokens from any public site |
| `poetry-simple_form` | The simple_form migration bridge |

## Status

Early release. The API is settling but not frozen; the CHANGELOG lists every breaking change.

## License

Available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
