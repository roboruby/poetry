# poetry-blode

[Blode Icons](https://blode.co) for Poetry: 4,193 icons across 2 styles,
**vendored at a pinned upstream commit and sanitized at vendor time**.
Render time never parses, never sanitizes, never touches the network.

```ruby
# Gemfile
gem "poetry-blode"
```

Requiring the gem registers each style with poetry-core's icon registry
under its own library key:

| Library | Style | Icons |
|---|---|---:|
| `:blode` | outline, 2px stroke | 2,139 |
| `:blode_filled` | filled | 2,054 |

Name the library per icon, or make one the default with
`config.icon_library`:

```erb
<%= poetry_icon(name: :"chevron-down", library: :blode) %>
<%= poetry_icon(name: :home, library: :blode_filled) %>
```

Porting from React: `ChevronDownIcon` from `blode-icons-react` is `name: :"chevron-down", library: :blode`; the filled twin is `library: :blode_filled`.

`poetry check` validates a literal icon name against the library the call
names. A dynamic name that misses raises in development and test, with a
did-you-mean, and renders the configured fallback in production.

## The pin

Icons vendor from [mblode/blode-icons](https://github.com/mblode/blode-icons) at a
**commit SHA, never a mutable tag** (blode-icons-react@1.0.0). The SHA on disk is
`icons/VENDORED_COMMIT`, exposed as `Poetry::Blode.vendored_commit`.
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
The vendored icons remain under Blode Icons's license, MIT, Copyright (c) 2026 Matthew Blode; see
`LICENSE-BLODE.txt`, which ships in the gem beside them.
