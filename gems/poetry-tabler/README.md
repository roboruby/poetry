# poetry-tabler

[Tabler Icons](https://tabler.io/icons) for Poetry: 6,238 icons across 2 styles,
**vendored at a pinned upstream commit and sanitized at vendor time**.
Render time never parses, never sanitizes, never touches the network.

```ruby
# Gemfile
gem "poetry-tabler"
```

Requiring the gem registers each style with poetry-core's icon registry
under its own library key:

| Library | Style | Icons |
|---|---|---:|
| `:tabler` | outline, Lucide's 24-unit 2px stroke | 5,184 |
| `:tabler_filled` | filled | 1,054 |

Name the library per icon, or make one the default with
`config.icon_library`:

```erb
<%= poetry_icon(name: :"brand-github", library: :tabler) %>
<%= poetry_icon(name: :home, library: :tabler_filled) %>
```

Porting from React: `IconHome` from `@tabler/icons-react` is `name: :home, library: :tabler`; `IconHomeFilled` is `library: :tabler_filled`.

`poetry check` validates a literal icon name against the library the call
names. A dynamic name that misses raises in development and test, with a
did-you-mean, and renders the configured fallback in production.

## The pin

Icons vendor from [tabler/tabler-icons](https://github.com/tabler/tabler-icons) at a
**commit SHA, never a mutable tag** (v3.49.0). The SHA on disk is
`icons/VENDORED_COMMIT`, exposed as `Poetry::Tabler.vendored_commit`.
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
The vendored icons remain under Tabler Icons's license, MIT, Copyright (c) 2020-2026 Paweł Kuna; see
`LICENSE-TABLER.txt`, which ships in the gem beside them.
