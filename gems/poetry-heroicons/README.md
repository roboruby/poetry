# poetry-heroicons

[Heroicons](https://heroicons.com) for Poetry: 1,288 icons across 4 styles,
**vendored at a pinned upstream commit and sanitized at vendor time**.
Render time never parses, never sanitizes, never touches the network.

```ruby
# Gemfile
gem "poetry-heroicons"
```

Requiring the gem registers each style with poetry-core's icon registry
under its own library key:

| Library | Style | Icons |
|---|---|---:|
| `:heroicons` | outline, 24px, 1.5px stroke | 324 |
| `:heroicons_solid` | solid, 24px | 324 |
| `:heroicons_mini` | mini, solid at 20px | 324 |
| `:heroicons_micro` | micro, solid at 16px | 316 |

Name the library per icon, or make one the default with
`config.icon_library`:

```erb
<%= poetry_icon(name: :home, library: :heroicons) %>
<%= poetry_icon(name: :home, library: :heroicons_mini) %>
```

Porting from React: `HomeIcon` from `@heroicons/react/24/outline` is `name: :home, library: :heroicons`; `/24/solid` is `:heroicons_solid`, `/20/solid` `:heroicons_mini`, `/16/solid` `:heroicons_micro`.

`poetry check` validates a literal icon name against the library the call
names. A dynamic name that misses raises in development and test, with a
did-you-mean, and renders the configured fallback in production.

## The pin

Icons vendor from [tailwindlabs/heroicons](https://github.com/tailwindlabs/heroicons) at a
**commit SHA, never a mutable tag** (v2.2.0). The SHA on disk is
`icons/VENDORED_COMMIT`, exposed as `Poetry::Heroicons.vendored_commit`.
Updating is deliberate: bump `PINNED_COMMIT` in `script/fetch_icons.rb`,
run it, review the diff.

```sh
bundle exec ruby script/fetch_icons.rb
```

Each style is one packed file under `icons/`, a line per icon holding its
sanitized **inner markup**; the Icon component owns the `<svg>` wrapper,
its drawing attributes and the ARIA contract. The fetch runs every SVG
through `Poetry::Core::Icons::Vendor`, which keeps only the inner markup
and removes `<script>`, `<foreignObject>`, `<title>`, external `<use>`
and `<image>` references and every `on*` handler. Never hand-edit `icons/`.

## License

The gem's own code is available under the [MIT License](https://opensource.org/licenses/MIT).
The vendored icons remain under Heroicons's license, MIT, Copyright (c) Tailwind Labs, Inc.; see
`LICENSE-HEROICONS.txt`, which ships in the gem beside them.
