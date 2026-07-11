# poetry data components

Contracts generated from the registry. `RULE` lines are constraints,
not suggestions. Options are keywords; content is the block.

## accordion (`poetry_accordion`)

Class: Poetry::Ui::Accordion::Component - BEM block `poetry-ui-accordion`.
Slot REQUIRED: with_item (at least one item) - a call without it raises.
- `collapsible:` (boolean) - default false
- `heading_level:` (symbol) - one of h2|h3|h4|h5|h6, default "h3"
- `open:` (list) - default "dynamic"
- `type:` (symbol) - one of single|multiple, default "single"
Slots: items (many; with_item yields NOTHING to the block - no |param|, write content directly).
- WIRING `poetry--core--accordion`: values collapsible, type; actions toggle; events poetry--core--accordion:change
- WIRING `poetry--core--roving-focus`: values loop, manageTabindex, orientation; actions keydown; events poetry--core--roving-focus:entry
- RULE: Items via with_item(value:, title:) { panel content } - value is the open-state key.
- RULE: type: :single (default) opens one at a time; pass collapsible: true to allow closing it.
- RULE: Server-render the open item(s) via open: %w[value] - never toggle data-open/data-closed by hand.
- RULE: heading_level: fits the page outline (h3 default) - the trigger button lives inside it.
- RULE: The chevron is built in - never add another indicator icon to the trigger.

## avatar (`poetry_avatar`)

Class: Poetry::Ui::Avatar::Component - BEM block `poetry-ui-avatar`.
Content block REQUIRED (the initials fallback) - a blockless call raises.
- `label:` (string)
- `size:` (symbol) - one of default|sm|lg, default "default"
- `src:` (string)
Slots: badge.
In blocks: `app-shell` - for a screen, start from the block (MCP compose/describe_block, or `bin/rails g poetry:block`), not from scratch.
- RULE: label: (the person's name) is REQUIRED - it is the avatar's accessible name (role=img).
- RULE: The content block is the fallback (initials) and is also required - it is what shows while the image loads or when it fails.
- RULE: The badge slot is decorative (a presence dot); put the status meaning in label:, not in the badge.
- RULE: Stack avatars with poetry_avatar_group; the overflow count is poetry_avatar_group_count.

## badge (`poetry_badge`)

Class: Poetry::Ui::Badge::Component - BEM block `poetry-ui-badge`.
Content block REQUIRED (the visible status text) - a blockless call raises.
- `variant:` (symbol) - one of default|secondary|destructive|outline|success|warning|info, default "default", required
In blocks: `data-index`, `section-card` - for a screen, start from the block (MCP compose/describe_block, or `bin/rails g poetry:block`), not from scratch.
- RULE: Badges are non-interactive status labels - never attach click handlers; use Button for actions.
- RULE: The visible text is the content block: render ... { "beta" } - there is no label: option.
- RULE: Pick the variant by intent (destructive = error states; success/warning/info = record status, e.g. Fulfilled/Processing/Syncing), never by color preference.
- RULE: Status badges on one surface read as a SET: keep one treatment family per table/list - the soft trio (+ outline for neutral) together, or the solid pair together; never a solid destructive pill inside a soft status column (design lint flags the mix).

## card (`poetry_card`)

Class: Poetry::Ui::Card::Component - BEM block `poetry-ui-card`.
- `title_tag:` (symbol) - one of h1|h2|h3|h4|h5|h6, default "h3"
Slots: title, description, action, footer.
In blocks: `app-shell`, `section-card` - for a screen, start from the block (MCP compose/describe_block, or `bin/rails g poetry:block`), not from scratch.
- RULE: Compose with the slots (title/description/action/footer) - never rebuild the header grid by hand.
- RULE: The card body is the content block; use CardAction for the header-corner control.
- RULE: The title renders as a real heading (h3 default) - set title_tag: to fit the page outline.

## carousel (`poetry_carousel`)

Class: Poetry::Ui::Carousel::Component - BEM block `poetry-ui-carousel`.
Slot REQUIRED: with_item (at least one slide) - a call without it raises.
- `label:` (string)
- `orientation:` (symbol) - one of horizontal|vertical, default "horizontal"
- `show_controls:` (boolean) - default true
Slots: items (many; with_item yields NOTHING to the block - no |param|, write content directly; with_item keywords: classes: ONLY; with_item REQUIRES a content block (the slide)).
- WIRING `poetry--core--carousel`: targets next, previous, viewport; values orientation; actions keydown, next, previous, scrollTo, scrolled; events poetry--core--carousel:select
- RULE: label: is REQUIRED - the carousel region's accessible name.
- RULE: Declare slides with with_item - the component stamps the slide roles (role=group + aria-roledescription=slide).
- RULE: Slides are REAL scroll content: they stay reachable by swipe, wheel, and keyboard even before JS - never gate content behind the buttons alone.
- RULE: Size slides with item classes (basis-full default; basis-1/3 for a strip).

## collapsible (`poetry_collapsible`)

Class: Poetry::Ui::Collapsible::Component - BEM block `poetry-ui-collapsible`.
Slot REQUIRED: with_trigger (the disclosure control) - a call without it raises.
- `open:` (boolean) - default false
Slots: trigger (with_trigger yields NOTHING to the block - no |param|, write content directly).
- WIRING `poetry--core--state`: targets content, trigger; values state; actions close, open, toggle
- RULE: The trigger is with_trigger { "label" } - a real button, wired for you (aria-expanded/controls).
- RULE: Server-render the initial state via open: - never toggle data-open/data-closed by hand.
- RULE: Content stays in the DOM when closed (hidden) - do not conditionally render it.
- RULE: For URL-controlled disclosure without JS, render open: from params - the same markup serves both.

## data_table (`poetry_data_table`)

Class: Poetry::Ui::DataTable::Component - BEM block `poetry-ui-data_table`.
Slot REQUIRED: with_column (at least one column) - a call without it raises.
- `caption:` (string)
- `empty_text:` (string) - default "No results."
- `filter:` (boolean) - default true
- `filter_label:` (string) - default "Filter"
- `filter_name:` (string) - default "q"
- `filter_placeholder:` (string) - default "Filter…"
- `frame:` (string)
Slots: columns (many; with_column REQUIRES a content block (the cell renderer - { |row| ... })).
- RULE: Build State.from_params(params, sortable: [...]) in the controller - NEVER order by raw params; the whitelist is what makes state.order_clause injection-safe.
- RULE: Column cell blocks RETURN the cell content ({ |row| row.title }) - they must not write to the template buffer.
- RULE: Sort/filter/page are URL state over GET links and a GET form. Row mutations (inline edit, row actions) belong to poetry-reactive components rendered inside cells - never to this component.
- RULE: Give the table a caption: - it is the table's accessible purpose.

## empty (`poetry_empty`)

Class: Poetry::Ui::Empty::Component - BEM block `poetry-ui-empty`.
- `media_variant:` (symbol) - one of default|icon, default "default"
- `title_tag:` (symbol) - one of h1|h2|h3|h4|h5|h6, default "h3"
Slots: media, title, description.
- RULE: An empty collection gets an Empty state with a next action - never a bare 'No results' div.
- RULE: Compose with the slots (media/title/description); the actions are the content block.
- RULE: The title renders as a real heading (h3 default) - set title_tag: to fit the page outline.
- RULE: media_variant: :icon gives the rounded muted icon tile; wrap a poetry_icon in with_media.

## item (`poetry_item`)

Class: Poetry::Ui::Item::Component - BEM block `poetry-ui-item`.
- `size:` (symbol) - one of default|sm|xs, default "default", required
- `variant:` (symbol) - one of default|outline|muted, default "default", required
- `media_variant:` (symbol) - one of default|icon|image, default "default"
- `tag:` (symbol) - default "div"
Slots: media, title, description, actions, header, footer.
- RULE: Rows live inside poetry_item_group (role=list) and each row passes role: "listitem" - a role=list parent with roleless children fails aria-required-children.
- RULE: Separate grouped rows with poetry_item_separator.
- RULE: Compose with the slots (media/title/description/actions); loose content lands in the content column after the description.
- RULE: media_variant: :icon for a glyph, :image for a thumbnail (sized/rounded automatically).
- RULE: A clickable row is tag: :a with href: - never wrap an Item in a bare <a>.

## table (`poetry_table`)

Class: Poetry::Ui::Table::Component - BEM block `poetry-ui-table`.
In blocks: `data-index` - for a screen, start from the block (MCP compose/describe_block, or `bin/rails g poetry:block`), not from scratch.
- RULE: Compose the table with the part helpers (poetry_table_header/_body/_row/_head/_cell) - they carry the data-slot + classes onto real thead/tbody/tr/th/td.
- RULE: A column header is poetry_table_head (a <th>); a data cell is poetry_table_cell (a <td>).
- RULE: Mark a selected row with data-selected on poetry_table_row - never a bespoke highlight class.

