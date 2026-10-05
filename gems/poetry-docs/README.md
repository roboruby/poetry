# poetry-docs

The documentation of the **poetry** family, poetryui.com, as a mountable
Rails engine under `gems/poetry-docs` in the family's repository. It consumes
the gems from the tree beside it exactly the way a real host does, and holds
the component and chart galleries, the guides, the live demos and the
machine surfaces. A host mounts it at the root of its docs hostname; a dummy
host under `test/dummy` serves and tests it here.

## Two jobs

1. **The docs.** A page per component and per chart with runnable examples,
   the guides (installation, forms, theming, testing, the agent surfaces),
   and the live demos (`live:`, `sync:`, windowing, Turbo morphs) —
   everything a static site cannot show, because the selling point is
   server-rendered SVG plus Hotwire behavior. The counts the docs quote
   about themselves come from the registry, never from prose.
2. **The standing install proof.** The engine's templates render every
   component and chart through the gems as shipped, with the installer's
   output (tokens, safelist, vendored layers) under `tailwind/`; the suite
   asserts a component page and a chart page still render through that
   pipeline, finished SVG included, on every push.

## What the engine serves besides pages

Every page has a markdown mirror (append `.md`, or send
`Accept: text/markdown`). Agents get `/llms.txt`, the component registry at
`/r/registry.json` (install with `bin/rails g poetry:add <name>`), the
installable skills under `/.well-known/skills` and `/agent-skills`, the
read-only MCP server at `/mcp`, and `/openapi.json` with its
`/.well-known/api-catalog`. The agent surfaces describe the gems alone,
never the host the engine is mounted in.

## Mounting it

The engine is versioned with the family and never published to RubyGems. A
host takes it from this repository at a release tag, and its production
image prunes the checkout to the engine after `bundle install`:

```ruby
gem "poetry-docs", github: "roboruby/poetry", tag: "v0.1.12", glob: "gems/poetry-docs/*.gemspec"
```

```ruby
# config/routes.rb: the docs at the root of their own hostname, ahead of
# every other route, with a terminal 404 so nothing else answers there.
constraints PoetryDocsHostConstraint.new do
  mount Poetry::Docs::Engine => "/"
  match "*path", to: proc { [ 404, { "content-type" => "text/plain" }, [ "Not found" ] ] }, via: :all
end
```

The host pins `@hotwired/turbo-rails`, `@hotwired/stimulus` and
`@hotwired/stimulus-loading` in its importmap; the engine's layouts link its
own stylesheet (`poetry_docs.css`, prebuilt and shipped) and name
`poetry_docs/application` as their entry point, so the host's JavaScript
and stylesheet never load on a docs page. Subscriptions post to Beehiiv
with `Poetry::Docs.configure { |c| c.beehiiv_api_key = ...; c.beehiiv_publication_id = ... }`.

## Running it

```sh
bundle install
bin/dev                       # the dummy host on http://localhost:4110
bundle exec rake              # tests, RuboCop, the stylesheet freshness gate
bundle exec rake poetry_docs:css      # after a change that affects scanned classes
bundle exec rake poetry_docs:refresh  # skills, API reference, search index, stylesheet
```

One bundle, one family: the Gemfile takes the poetry gems from the tree by
path, so the docs always describe the code beside them and nothing is
pinned. CI runs the default chain on that bundle, so every push proves the
tree installs and renders, and the reference-data job checks that
`data/api/*.json`, the skills, the search index and the stylesheet match
the gems they were generated from.

## After a family release

Nothing, here. The release train's bump stamps the version into the family
and runs `poetry_docs:refresh` in the same commit. The host that serves
poetryui.com moves its tag.

## The installer

Never run `poetry:install` against the engine or its dummy host: it would
re-inject the unscoped default theme into the Tailwind entry, and the nine
scoped themes under `tailwind/styles` would leak its tokens. After gem
fragment changes, run `ruby script/build_style_registry.rb` (it refreshes
the installed slots under `tailwind/poetry` byte-for-byte and rewraps the
nine themes) and then `bundle exec rake poetry_docs:css`.
