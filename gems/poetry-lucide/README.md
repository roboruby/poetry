# poetry-lucide

The default poetry icon set: [Lucide](https://lucide.dev)'s 1,746 icons,
**vendored at a pinned upstream commit and sanitized at vendor time** —
render time never parses, never sanitizes, never touches the network.

```ruby
# Gemfile
gem "poetry-lucide"
```

Requiring the gem registers the set with poetry-core's icon registry as
`:lucide`; poetry-ui's Icon component finds it as the default library
with no further wiring:

```erb
<%= poetry_icon(name: :plus) %>                      <%# decorative: aria-hidden %>
<%= poetry_icon(name: :search, label: "Search") %>   <%# standalone: role="img" + aria-label %>
```

Each file under `icons/` holds an icon's sanitized **inner markup** —
the Icon component owns the `<svg>` wrapper and the ARIA contract riding
on it. `poetry check` validates icon-name literals statically against
this set; a dynamic name that misses raises in dev/test (with a
did-you-mean) and renders the configured fallback in production.

## The pin

Icons vendor from lucide-icons/lucide at a **commit SHA, never a mutable
tag**. The SHA on disk is recorded in `icons/VENDORED_COMMIT` and exposed
as `Poetry::Lucide.vendored_commit`. Updating is deliberate: bump
`PINNED_COMMIT` in `script/fetch_icons.rb`, run it, review the diff.

```sh
bundle exec ruby script/fetch_icons.rb
```

The fetch pipeline strips `<script>`, `<foreignObject>`, `<use>`/`<image>`
with external hrefs, and every `on*` handler attribute from each SVG
before writing it — sanitization runs once at vendor time so the render
path can trust the files by construction. Never hand-edit `icons/`.

## License

Available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
The vendored Lucide icons remain under Lucide's ISC license — see
`LICENSE-LUCIDE.txt`, which ships in the gem beside them.
