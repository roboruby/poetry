# Stable component ids: `key:`, the ladder, and Turbo morph

Every poetry component mints DOM ids to wire its internal ARIA and
pairing relationships (`aria-controls`, `label[for]`, floating anchors,
SVG defs). How those ids are chosen decides whether Turbo morph can pair
your components across renders — and whether cached fragments stay
composable. The ladder, in precedence order:

1. **`id:` — explicit caller identity.** The root id; every internal id
   derives from it (`<id>-trigger`, `<id>-content`, item ids).
   Order-independent, cache-safe, morph-stable. Your namespace: if you
   pass `id: "settings"`, poetry derives `settings-trigger` etc. — don't
   also hand-author those.
2. **`key:` — semantic identity.** A record or a literal:
   `poetry_dropdown_menu(key: message)` derives
   `poetry-dropdown-menu-message_42` via Rails' own `dom_id`, so identity
   follows the *record* — a sorted or filtered collection morphs with
   state staying on the right row. Literals parameterize
   (`key: "faq"` → `poetry-accordion-faq`).
3. **Form components** ride the form builder's attribute-derived ids.
4. **Random fallback.** Without identity, ids are random per render:
   under a Turbo morph the component is *replaced* (open state, focus,
   and JS state reset). That is deliberate — an unkeyed component must
   over-replace rather than ever falsely retain state on the wrong
   record.

## When you MUST pass identity

- **Collections**: `<% @messages.each do |m| %><%= poetry_dropdown_menu(key: m) ... %>`
  — otherwise every morphing reorder replaces every row's component.
- **Fragment-cache blocks**: an unkeyed component freezes a random id
  into the cached HTML; replays can collide with fresh ids and morphs
  can't pair it. The invariant: *cached HTML is safe only when every id
  frozen into it remains unique under every composition and replay of
  that HTML.*
- **Broadcast / stream partials destined for `turbo_stream.morph`**:
  the morph pairs against the live DOM by id. (Plain
  `append`/`replace` streams are safe unkeyed — ids churn per broadcast
  but stay unique and internally consistent.)
- **Repeated new-record forms**: `key: record` on an unsaved record
  derives `new_<model>` — two of those collide; pass literal keys.

`poetry:check` warns on the first two (`stable-identity/cache`,
`stable-identity/collection`) — heuristics over conventional ERB, not
proofs. The runtime complement is `poetry_id_integrity_script` (render
in your development layout's `<head>`): it scans the composed page for
duplicate ids after every load, frame load, morph, and stream insertion
— the only check that sees real cross-template composition.

## Obfuscating record ids

`key:` derives through `dom_id`, which reads your model's `to_key`. To
keep primary keys out of the DOM app-wide — poetry ids, your own
`dom_id` calls, `turbo_frame_tag`, and Turbo Stream broadcast targets
all staying consistent — override it at the model
([the dom_id-without-primary-id pattern](https://railsdesigner.com/dom-id-without-primary-id/)):

```ruby
def to_key = [slug]
def to_param = slug
```

Or pass a literal: `key: message.public_uid`. poetry deliberately never
reads slugs itself: slugs are mutable and recyclable (a freed slug
claimed by another record would transfer identity), and poetry
preferring them while your own `dom_id` stayed pk-based would split the
app into two id vocabularies.

## What morph identity does and does not preserve

With a paired (keyed) component, Turbo morph keeps the *DOM node*:
Stimulus controller instances, JS properties, scroll state — everything
riding the element object. Two things never survive regardless of ids,
by browser/Turbo design:

- **Focus across a reorder** — a moved node detaches and reinserts,
  which blurs it. Not an id failure.
- **User-typed input values** — idiomorph deliberately syncs values to
  server truth. User-held input state is `data-turbo-permanent`
  territory.

## The sequence mode (opt-in, experimental)

`Poetry::Core::Config.current.stable_id_mode = :sequence` seeds a
per-request deterministic id sequence (seed: `request.path`, matching
Turbo's page-refresh definition; override via `stable_id_seed`). Same
page → identical ids → byte-stable responses: Turbo morph pairs even
unkeyed components, and body-hash ETags can match on responses with no
other request-varying output.

**Read the hazards before enabling — they are why this is not the
default:**

- **Same-path turbo-frames collide deterministically**: two frames
  loading `/widgets?a` and `/widgets?b` both seed from `/widgets` and
  draw identical id sequences into one composed page. poetry's own
  `Deferred` regions are turbo-frames.
- **Positional false identity**: a reordered same-type collection pairs
  by *position*, so an open menu's state can land on the WRONG record
  after a morphing re-sort. Use `key:` for collections, always —
  the sequence is for byte-stable static/content pages.

The allocator is pinned by a golden-vector test: a gem upgrade cannot
silently re-identify sequence-mode pages.

## HTTP caching, ETags, and CSRF (what ids do and don't buy)

- **Body-hash ETags** (`Rack::ETag`) match only on byte-identical
  responses. Stable ids remove one source of churn, but
  `csrf_meta_tags` masks a fresh token per render — a page with zero
  forms still varies if the standard layout emits it. The realistic
  scope: responses with *no* request-varying output.
- **`fresh_when`/`stale?` are unrelated to ids**: record-derived
  validators never hash the body; stable ids do not change their hit
  rate. They remain the right 304 mechanism for form pages — Rails CSRF
  tokens are per-session (an older masked token still validates while
  the session lives), with two cautions: a *session reset* invalidates
  tokens inside browser-cached pages (represent such dependencies in
  the `etag:` hook), and `per_form_csrf_tokens` scopes tokens to an
  action/method when enabled.
- **Fragment caching**: keep the token-bearing `<form>` tag *outside*
  the cached fragment (a cached hidden token serves one session's token
  to everyone); see `docs/caching.md` for the full recipe and the
  replay invariant.
