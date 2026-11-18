# poetry-phosphor

[Phosphor Icons](https://phosphoricons.com) for Poetry: 7,488 icons across 6 styles,
**vendored at a pinned upstream commit and sanitized at vendor time**.
Render time never parses, never sanitizes, never touches the network.

```ruby
# Gemfile
gem "poetry-phosphor"
```

Requiring the gem registers each style with poetry-core's icon registry
under its own library key:

| Library | Style | Icons |
|---|---|---:|
| `:phosphor` | regular weight, filled shapes on a 256 grid | 1,248 |
| `:phosphor_bold` | bold weight, filled shapes on a 256 grid | 1,248 |
| `:phosphor_duotone` | duotone weight, filled shapes on a 256 grid | 1,248 |
| `:phosphor_fill` | fill weight, filled shapes on a 256 grid | 1,248 |
| `:phosphor_light` | light weight, filled shapes on a 256 grid | 1,248 |
| `:phosphor_thin` | thin weight, filled shapes on a 256 grid | 1,248 |

Name the library per icon, or make one the default with
`config.icon_library`:

```erb
<%= poetry_icon(name: :house, library: :phosphor) %>
<%= poetry_icon(name: :house, library: :phosphor_bold) %>
```

Porting from React: `<House weight="bold" />` from `@phosphor-icons/react` is `name: :house, library: :phosphor_bold`; no weight is `library: :phosphor`.

`poetry check` validates a literal icon name against the library the call
names. A dynamic name that misses raises in development and test, with a
did-you-mean, and renders the configured fallback in production.

## The pin

Icons vendor from [phosphor-icons/core](https://github.com/phosphor-icons/core) at a
**commit SHA, never a mutable tag** (v2.0.8). The SHA on disk is
`icons/VENDORED_COMMIT`, exposed as `Poetry::Phosphor.vendored_commit`.
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
The vendored icons remain under Phosphor Icons's license, MIT, Copyright (c) 2023 Phosphor Icons; see
`LICENSE-PHOSPHOR.txt`, which ships in the gem beside them.
