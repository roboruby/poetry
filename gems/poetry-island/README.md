# poetry-island

Poetry's client islands: a bounded mount inside server-rendered HTML for
the rare widget whose state lives on the client and changes many times a
second. An editor, a canvas, a map, a 3D scene. Everything else in a Poetry
page stays a component with a Stimulus behavior; this gem is the declared
exception, and the markup says so.

```erb
<%= poetry_island(import: "islands/map", props: { center: [lat, lng] }, class: "h-80") do %>
  <%= image_tag "office-map.png", alt: "The office, on a map" %>
<% end %>
```

- **The shell is the server render.** The block is what the page shows
  before the module mounts and whenever it cannot: in print, under a failed
  import, in a Turbo preview. Put the content a reader needs there.
- **A module is any file that exports `mount(element, props)`** and returns
  `{ unmount, update? }`. A plain script, a vendored kernel or a bundle
  built once all mount the same way; the gem ships no framework and no
  bundler. `import:` is an importmap specifier the host pins.
- **One controller handles the Turbo lifecycle** for every island: mount on
  connect, unmount on disconnect, a morph refresh keeps the island and hands
  it the server's new props, a cached snapshot's dead root is cleared.
- **State leaves through the form.** `name:` renders a hidden input inside
  the island, where a morph leaves it alone; the module writes to
  `props.input`, and a submit carries it.

## Install

```ruby
gem "poetry-island"
```

```sh
bin/rails g poetry:install
```

The installer registers the island controller in
`app/javascript/controllers/index.js` and pins `app/javascript/islands/` as
`islands/*`, so `app/javascript/islands/map.js` is `import: "islands/map"`.

## Development

```sh
bundle exec rake   # Ruby tests, RuboCop, the registry gate, then npm test
npm run manifest   # regenerate config/controllers_manifest.json after changing the controller
```
