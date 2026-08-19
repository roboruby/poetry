# Caching poetry components

Fragment caching is how server-rendered UI gets fast: cache the rendered
fragment, nest caches inside caches (russian-doll), and let `touch`
cascades invalidate exactly what changed. Poetry components are ordinary
server-rendered markup, so all of it applies — with one blind spot you
must know about, and a few rules that keep fragments cacheable at all.

## The digest blind spot (read this section even if you skip the rest)

Rails invalidates fragment caches through *template digests*: each
template's cache keys include a hash of its source and of every template
it renders. That mechanism cannot see poetry, twice over:

1. **Discovery** — the dependency tracker scans for `render` calls.
   `<%= poetry_card do %>` is a helper call; no tracker recognizes it,
   so the component is never registered as a dependency.
2. **Resolution** — poetry's templates live in the gem, outside the
   host's view paths. Even a discovered dependency could not be resolved
   into the digest tree.

The consequence is silent: **a cached fragment containing poetry markup
is NOT invalidated when you upgrade poetry.** After an upgrade that
changed a component's template or class, hosts that fragment-cache keep
serving the old markup from the cache — no error, no warning, stale UI.
(For ViewComponent generally this is
[view_component#234](https://github.com/ViewComponent/view_component/issues/234);
tildeio's [view_component-cache_digest](https://github.com/tildeio/view_component-cache_digest)
proof-of-concept fixes it for `render SomeComponent.new` calls in
`app/components` — but poetry renders through helpers from a gem, which
is outside even that fix.)

## The recipe: version-keyed cache keys

Put the poetry version in the cache key of any fragment whose markup
includes poetry helpers:

```erb
<% cache [@post, Poetry::Ui::VERSION] do %>
  <%= poetry_card do |card| %>
    ...
  <% end %>
<% end %>
```

- Every poetry upgrade changes `Poetry::Ui::VERSION`, so every
  version-keyed fragment misses once and re-renders fresh.
- With nested (russian-doll) caches, the version key belongs on **every
  fragment that directly contains poetry markup** — an inner fragment's
  key does not protect an outer one that also renders helpers.
- Charts too: fragments containing `poetry_chart` add
  `Poetry::Charts::VERSION`.

A convenient app-side helper keeps call sites short:

```ruby
# app/helpers/application_helper.rb
def cache_with_poetry(*keys, &block)
  cache([*keys, Poetry::Ui::VERSION], &block)
end
```

**Development note**: with path-pinned poetry checkouts the VERSION
constant does not change per edit. Leave `rails dev:cache` off while
iterating on components (the default), or clear the cache after gem
edits.

## Rules for markup that can be cached at all

The rules below are what make russian-doll caching work in practice
(the Basecamp playbook, stated for poetry):

- **No viewer conditionals inside the fragment.** A cached fragment is
  the same bytes for every viewer — `if current_user.admin?` inside a
  cached fragment poisons the cache for everyone else. Split the
  fragment, or move the decision out of the cacheable markup.
- **Personalization is decoration.** Render the shared markup once,
  cache it, and let a thin client layer decorate per viewer:
  `data-*` attributes + a Stimulus controller reading client state.
  Poetry's own color scheme works exactly this way — the cached markup
  is theme-neutral; `poetry_color_scheme_script` applies the viewer's
  mode at paint time.
- **Timestamps and counters stay out, or get their own fragment.**
  Anything per-request (relative times, unread counts) either renders
  outside the cache, in its own smaller fragment, or as decoration.
- **`touch: true` up the ownership chain** is what makes record-keyed
  invalidation cascade — the poetry version key composes with it; it
  never replaces it.

## Copy-ins (poetry:add)

Components you copy into the app live under `app/components` and are
inside the host's digest tree — but discovery still fails, because they
render through helpers. Two options:

- `# Template Dependency: components/<name>/component` magic comments in
  templates that render the copy-in — the standard Rails escape hatch;
  the Digestor resolves them like any other dependency.
- For `render SomeComponent.new(...)`-style call sites, tildeio's
  view_component-cache_digest tracks them automatically.

The version-key recipe also covers copy-ins during poetry upgrades that
re-copy (`poetry:diff` tells you when source moved).

## The designed follow-up (not shipped)

Poetry's registry knows every `poetry_*` helper and its component files
— an exact static map, stronger than any `render`-scanning heuristic
(`poetry check` already parses call sites this way). A registry-driven
dependency tracker plus a resolver contributing gem-file digests would
make `<% cache @post do %>` invalidate automatically on poetry upgrades,
with no version-key discipline. Recorded as a lead; the tildeio
proof-of-concept above is the reference implementation for the hook
points. Until then: version keys.

## Ids inside cached fragments (the replay invariant)

Fragment caching replays HTML that was rendered once — including every
DOM id frozen into it at render time. The invariant that makes that
safe:

> **Cached HTML is safe only when every id frozen into it remains
> unique under every composition and replay of that cached HTML.**

Random ids satisfy uniqueness on the first render but cannot be paired
by Turbo morph afterwards, and the same cached fragment rendered twice
on one page duplicates even its random ids. So the rule is: **poetry
components inside a `cache` block take `key:` (a record, or a literal)
or an explicit `id:`.** A keyed component's HTML is a pure function of
its inputs — cached copies and fresh renders can never disagree.
`poetry:check` warns on unkeyed components in cache blocks
(`stable-identity/cache`), and `poetry_id_integrity_script` (dev
layouts) catches what static analysis can't: the composed page. Full
identity story: `docs/stable-ids.md`.

The same rule covers every other render that escapes the request cycle:
broadcast partials destined for `turbo_stream.morph`, and pre-rendered
HTML persisted anywhere.

## HTTP caching, ETags, and CSRF

Three separate mechanisms, often conflated:

- **`Rack::ETag` (body-hash) 304s** need byte-identical responses.
  poetry's keyed/sequence-stable ids remove the component-id churn, but
  `csrf_meta_tags` masks a fresh token every render — the standard
  layout makes even formless pages vary. Realistic scope: responses
  with no request-varying output at all.
- **`fresh_when` / `stale?`** compute validators from records *before*
  rendering — poetry ids are irrelevant to their hit rate, and they are
  the right 304 mechanism for form pages: CSRF tokens are per-session,
  so an older masked token inside a browser-reused page still submits.
  Two cautions: a session reset invalidates tokens inside
  browser-cached pages — represent such dependencies via the `etag:`
  hook — and `per_form_csrf_tokens`, when a host enables it, scopes
  tokens to a form's action/method.
- **Fragment caching and forms**: never cache the token — keep the
  `<form>` tag outside the cached fragment and cache the expensive
  content within. A cached hidden token field serves one session's
  token to every visitor.
