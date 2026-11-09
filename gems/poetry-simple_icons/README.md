# poetry-simple_icons

[Simple Icons](https://simpleicons.org) for Poetry: 3,466 icons across one style,
**vendored at a pinned upstream commit and sanitized at vendor time**.
Render time never parses, never sanitizes, never touches the network.

```ruby
# Gemfile
gem "poetry-simple_icons"
```

Requiring the gem registers each style with poetry-core's icon registry
under its own library key:

| Library | Style | Icons |
|---|---|---:|
| `:simple_icons` | brand logos, filled, one colour | 3,466 |

Name the library per icon, or make one the default with
`config.icon_library`:

```erb
<%= poetry_icon(name: :github, library: :simple_icons, label: "GitHub") %>
```

Porting from React: `SiGithub` from `@icons-pack/react-simple-icons` is `name: :github, library: :simple_icons`; its `color="default"` is `style: "color: ##{Poetry::SimpleIcons.brand(:github)[:hex]}"`.

`poetry check` validates a literal icon name against the library the call
names. A dynamic name that misses raises in development and test, with a
did-you-mean, and renders the configured fallback in production.

## Brand colours

`Poetry::SimpleIcons.brand(:github)` returns the brand's name and colour from
Simple Icons' data, `{ title: "GitHub", hex: "181717" }`, for a logo in its own
colour:

```erb
<%= poetry_icon(name: :github, library: :simple_icons,
                style: "color: ##{Poetry::SimpleIcons.brand(:github)[:hex]}") %>
```

## Trademarks

The icons are brand logos. Simple Icons dedicates its SVG data to the public
domain (CC0), but the marks stay their owners' trademarks. Read
`DISCLAIMER-SIMPLE-ICONS.md`, which ships in the gem, before using one.

## The pin

Icons vendor from [simple-icons/simple-icons](https://github.com/simple-icons/simple-icons) at a
**commit SHA, never a mutable tag** (16.35.0). The SHA on disk is
`icons/VENDORED_COMMIT`, exposed as `Poetry::SimpleIcons.vendored_commit`.
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
The vendored icons remain under Simple Icons's license, CC0 1.0 Universal (public domain dedication); see
`LICENSE-SIMPLE-ICONS.txt`, which ships in the gem beside them.
