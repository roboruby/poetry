# poetry-hugeicons

[Hugeicons (the free set)](https://hugeicons.com) for Poetry: 6,137 icons across one style,
**vendored at a pinned upstream commit and sanitized at vendor time**.
Render time never parses, never sanitizes, never touches the network.

```ruby
# Gemfile
gem "poetry-hugeicons"
```

Requiring the gem registers each style with poetry-core's icon registry
under its own library key:

| Library | Style | Icons |
|---|---|---:|
| `:hugeicons` | stroke rounded, 1.5px; each path carries its own stroke | 6,137 |

Name the library per icon, or make one the default with
`config.icon_library`:

```erb
<%= poetry_icon(name: :"home-01", library: :hugeicons) %>
```

Porting from React: `Home01Icon` from `@hugeicons/core-free-icons` is `name: :"home-01", library: :hugeicons`.

`poetry check` validates a literal icon name against the library the call
names. A dynamic name that misses raises in development and test, with a
did-you-mean, and renders the configured fallback in production.

## The pin

Icons vendor from [hugeicons/hugeicons](https://github.com/hugeicons/hugeicons) at a
**commit SHA, never a mutable tag** (main, 2026-09-23). The SHA on disk is
`icons/VENDORED_COMMIT`, exposed as `Poetry::Hugeicons.vendored_commit`.
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
and `<image>` references and every `on*` handler, and turns the upstream's hardcoded colours into `currentColor`. Never hand-edit `icons/`.

## License

The gem's own code is available under the [MIT License](https://opensource.org/licenses/MIT).
The vendored icons remain under Hugeicons's license, MIT, Copyright (c) 2025 Hugeicons; see
`LICENSE-HUGEICONS.txt`, which ships in the gem beside them.
