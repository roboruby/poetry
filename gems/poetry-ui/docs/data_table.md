# DataTable — the server-driven recipe

poetry's DataTable is **not** a client table engine (shadcn's is a TanStack
recipe). It is poetry's Table + sortable headers + a filter box + Pagination,
with sorting/filtering/pagination as **URL state** — shareable,
crawlable, and back-button-correct, because GET is the only transport the
back button can replay. The data stays with the host: your controller owns
the scope; the component owns the markup, the URLs, and the accessibility.

## The controller

`State.from_params` sanitizes at the door: `sort` survives only if it is in
the `sortable:` whitelist and `dir` only as asc/desc — so `state.order_clause`
is injection-safe **by construction**, never by caller discipline.

```ruby
class NotesController < ApplicationController
  PER = 20

  def index
    @state = Poetry::Ui::DataTable::State.from_params(
      params, sortable: %w[title created_at], default_sort: "created_at", default_dir: "desc"
    )

    scope = Note.all
    scope = scope.where("title LIKE ?", "%#{Note.sanitize_sql_like(@state.q)}%") if @state.q
    @total = (scope.count / PER.to_f).ceil
    @notes = scope.order(@state.order_clause).offset((@state.page - 1) * PER).limit(PER)
  end
end
```

## The view

```erb
<%= poetry_data_table(rows: @notes, state: @state, total: @total,
                      caption: "Your notes, most recent first.",
                      path: ->(p) { notes_path(**p) }) do |table| %>
  <% table.with_column("Title", key: :title, sortable: true) { |note| note.title } %>
  <% table.with_column("Created", key: :created_at, sortable: true) { |note| l(note.created_at.to_date) } %>
<% end %>
```

- `path:` is a callable `params-hash -> url` (the Pagination convention).
  With `{}` it must return the bare collection URL — the filter form's
  action.
- **Cell blocks return the cell content** (`{ |note| note.title }`); they
  must not write to the template buffer. Compose helpers for rich cells —
  they return safe strings.
- A sortable column whose `key:` is missing from the controller's
  `sortable:` whitelist **raises at render** — view/controller drift
  surfaces immediately, not as a silently dead header.

## Accessibility

The active column's `<th>` carries `aria-sort="ascending|descending"` (the
APG announcement — one column at a time). Sort affordances are real links
(keyboard, middle-click, and copy-link all work). The filter is a labelled
GET form with `role="search"`; Enter submits natively — zero JS.

## Scoped updates (optional)

Pass `frame: "notes"` to wrap the table in a
`<turbo-frame id="notes" data-turbo-action="advance">`: hosts with Turbo
swap only the table while the URL still advances. Your response must render
the same frame id. Without Turbo the frame element is inert and every link
still works as a full navigation.

## Filter-as-you-type (optional)

The v1 filter submits on Enter. For live filtering, add a debounced
`requestSubmit` on the input (a three-line Stimulus controller in your app),
keeping the same GET form — the URL contract is unchanged.

## Row mutations: compose the reactive tier

Sorting/filter/page are *view* state and belong in the URL. Row *mutations*
(inline edit, toggle, row actions) belong to **poetry-reactive**: render a
reactive component inside a cell and the two tiers compose — the table's
GET round trip re-renders the collection; the row's signed POST action
mutates one record and replaces one row by id.

```erb
<% table.with_column("Title", key: :title, sortable: true) do |note| %>
  <%# a poetry-reactive component: signed GlobalID identity, default-deny
      actions, replace-by-id - see the poetry-reactive README %>
  <%= render NoteTitleCellComponent.new(note: note) %>
<% end %>
```

Each tier owns the state that belongs to it: **the URL for the view, the
database (via signed identity) for the data.**
