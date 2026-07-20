# Optimistic forms

`poetry_optimistic_form` gives a Turbo form optimistic UI: the predicted
result paints the instant the user submits, and the server is consulted
for correction only when it rejects the change. The pattern is ported
from The Hotwire Club's toolbox onto poetry's controller
channel.

The design bet is **one vocabulary**: you author the optimistic update
as a Turbo Stream inside a `<template>`, which is the same language the
server answers in. Prediction and truth are the same kind of artifact —
there is no bespoke client-side DOM patching to keep in sync.

## How it works

1. **On `turbo:submit-start`** the `poetry--core--optimistic-form`
   controller clones every `optimistic_template` into the document.
   Turbo processes the contained `<turbo-stream>` and paints the
   predicted state immediately — no round trip.
2. **On `turbo:submit-end`** the controller looks at
   `event.detail.success`:
   - **Success**: nothing happens. The optimistic paint already shows
     the new state (or the server's own targeted stream corrected it).
   - **Failure**: the controller appends
     `<turbo-stream action="refresh">`. Turbo re-fetches the page and —
     because refreshes morph — seamlessly restores authoritative truth.

The happy path costs zero extra requests; a full refresh only ever runs
when the server rejects the change, which is exactly when you want
authority.

## Prerequisites

Reconciliation rides Turbo **morph** page refreshes. Add these to your
layout `<head>` (the install generator reminds you):

```html
<meta name="turbo-refresh-method" content="morph">
<meta name="turbo-refresh-scroll" content="preserve">
```

## Basic usage

A favorite toggle. The template predicts the *toggled* state; the button
shows the *current* one:

```erb
<%= poetry_optimistic_form(model: photo, attribute_name: :favorite, value: !photo.favorite) do |form| %>
  <%= form.optimistic_template dom_id(photo, "favorite-icon"), favorite_icon(!photo.favorite) %>
  <%= form.button do %><%= favorite_icon(photo.favorite) %><% end %>
<% end %>
```

A submit that updates a region elsewhere on the page (a cart counter):

```erb
<%= poetry_optimistic_form(url: cart_items_path, method: :post, attribute_name: :photo_id, value: photo.id) do |form| %>
  <%= form.optimistic_template "cart-count", (@cart_count + 1) %>
  <%= poetry_button(type: :submit) { "Add to cart" } %>
<% end %>
```

Declare several `optimistic_template`s to paint several regions from one
submit; all of them apply.

## The server contract

This is the part the client cannot enforce, so it is stated here once
and precisely:

- **Success: respond `204 No Content`** (or a targeted Turbo Stream —
  see the contention section). **Never redirect.** A redirect combined
  with morph refreshes is itself a full page load, which defeats the
  optimism you just painted.
- **Failure: respond `4xx`** (typically `422`) so `event.detail.success`
  is false and the client reconciles. Set a flash first if you want it
  surfaced after the refresh.

```ruby
def update
  @photo = Photo.find(params[:id])

  if @photo.update(photo_params)
    head :no_content
  else
    flash[:alert] = "Your change could not be saved."
    head :unprocessable_entity
  end
end
```

## The submitted value

Two ways to carry the toggled value, pick one per form:

- **Automatic**: pass `attribute_name:`/`value:` to the helper and a
  hidden field is injected for you. `value: false` is preserved — a
  favorite toggle legitimately submits `false`; only `nil`/omitted
  suppresses the field.
- **Explicit**: call `form.optimistic_hidden_field :favorite, value:
  !photo.favorite` where you want it. This suppresses the automatic
  injection (the block is captured first, so your call wins).

## Predictions that can be wrong: authoritative correction

Under contention the true result can differ from the prediction (a
shared counter, a vote total). Return a **targeted Turbo Stream on
success** instead of a 204 — Turbo applies it over the optimistic guess
with no client change needed. To keep prediction and truth from
drifting, render the fragment from a **single partial used in both
places**:

```erb
<%# app/views/photos/_favorite_icon.html.erb — the single source of truth %>
<span id="<%= dom_id(photo, "favorite-icon") %>"><%= favorite_icon(photo.favorite) %></span>
```

```erb
<%# the prediction: the same partial, opposite state %>
<%= form.optimistic_template do %>
  <%= turbo_stream.update dom_id(photo, "favorite-icon") do %>
    <%= favorite_icon(!photo.favorite) %>
  <% end %>
<% end %>
```

```ruby
# the authoritative success response
render turbo_stream: turbo_stream.update(
  ActionView::RecordIdentifier.dom_id(@photo, "favorite-icon"),
  partial: "photos/favorite_icon", locals: { photo: @photo }
)
```

## Authoring streams directly

The positional form (`target, content`) wraps a `turbo_stream.update`
for you. Pass a block to author any stream(s) yourself:

```erb
<%= form.optimistic_template do %>
  <%= turbo_stream.update("cart-count") { @cart_count + 1 } %>
  <%= turbo_stream.remove(dom_id(photo, "add-button")) %>
<% end %>
```

## When to reach for it

Use an optimistic form where the prediction is knowable and the action
is small and reversible: favorite/like toggles, add-to-cart, counters,
subscribe buttons, reorderings the user just performed. Do **not** use
it where the server decides the outcome (payments, permission-dependent
transitions, anything whose failure is common) — a plain Turbo form with
`poetry_button(loading: true)` states is the honest UI there.

## Notes

- **Escaping**: template content is trusted developer markup, exactly
  like any `turbo_stream.update` body. Never interpolate unsanitized
  user input into a prediction.
- **Burst safety**: `apply` is throttled per form (200ms) so rapid
  resubmits cannot stack duplicate clones; the first paint is always
  immediate.
- **Vocabulary**: the helper wires `data-controller` and both
  `turbo:submit-*` actions for you and composes with any `data:` you
  pass. The check tool knows the helper (keywords only, yields the form
  builder).
