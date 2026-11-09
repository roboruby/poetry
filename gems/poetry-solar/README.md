# poetry-solar

[Solar Icon Set](https://www.figma.com/community/file/1166831539721848736) for Poetry: 8,706 icons across 6 styles,
**vendored at a pinned upstream commit and sanitized at vendor time**.
Render time never parses, never sanitizes, never touches the network.

```ruby
# Gemfile
gem "poetry-solar"
```

Requiring the gem registers each style with poetry-core's icon registry
under its own library key:

| Library | Style | Icons |
|---|---|---:|
| `:solar` | linear, 1.5px stroke | 1,451 |
| `:solar_bold` | bold, filled | 1,451 |
| `:solar_bold_duotone` | bold duotone | 1,451 |
| `:solar_broken` | broken lines | 1,451 |
| `:solar_line_duotone` | line duotone | 1,451 |
| `:solar_outline` | outline, filled outlines | 1,451 |

Name the library per icon, or make one the default with
`config.icon_library`:

```erb
<%= poetry_icon(name: :home, library: :solar) %>
<%= poetry_icon(name: :home, library: :solar_bold_duotone) %>
```

Porting from React: `HomeIcon` from `@solar-icons/react/linear` is `name: :home, library: :solar`; `/bold` is `:solar_bold`, `/bold-duotone` `:solar_bold_duotone`, `/broken` `:solar_broken`, `/line-duotone` `:solar_line_duotone` and `/outline` `:solar_outline`.

`poetry check` validates a literal icon name against the library the call
names. A dynamic name that misses raises in development and test, with a
did-you-mean, and renders the configured fallback in production.

## Attribution

The Solar icons are 480 Design's work under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), which asks every
copy to credit the creator, link the source and the license, and say what
changed. The gem does that for you:

- Every icon renders with an invisible credit inside its `<svg>`, an HTML
  comment naming 480 Design, the source, the license and the changes
  (`Poetry::Solar::ATTRIBUTION`). Any page that serves the icon carries it.
  Do not strip HTML comments from these icons.
- `Poetry::Solar.credit` is a one-line credit for a visible credits or about
  page, which Creative Commons recommends on top of the minimum.
- The gem ships the license text (`LICENSE-SOLAR.txt`) and a `NOTICE`
  naming the creator, the source and the modifications.

CC BY 4.0 has no ShareAlike term: your app and the rest of Poetry keep their
own licenses. If 480 Design asks for the credit to be removed, it must be.

## The pin

Icons vendor from [saoudi-h/solar-icons](https://github.com/saoudi-h/solar-icons) at a
**commit SHA, never a mutable tag** (main, 2026-10). The SHA on disk is
`icons/VENDORED_COMMIT`, exposed as `Poetry::Solar.vendored_commit`.
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
The vendored icons remain under Solar Icon Set's license, CC BY 4.0, by 480 Design; see
`LICENSE-SOLAR.txt`, which ships in the gem beside them, and the Attribution section above.
