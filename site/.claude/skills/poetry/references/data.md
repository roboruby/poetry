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
- PART `accordion` - The list root - both controllers (the open-set machine and roving focus) ride here | states: data-orientation=vertical (always vertical - the only axis the accordion ships)
- PART `accordion-item` - One value-keyed section wrapping its header and panel | states: data-open (the item is expanded (server-rendered from open:; the controller flips the pair at runtime)); data-closed (the item is collapsed); data-value (the item's open-state key (always present))
- PART `accordion-header` - The heading element (heading_level:, h3 default) hosting the trigger button
- PART `accordion-trigger` - The toggle button inside the header - the chevron rotation rides aria-expanded, not a data attribute | states: data-panel-open (its panel is open (Base UI trigger parity, controller-written; absent while closed))
- PART `accordion-content` - The role=region panel - the presence animation and the measured height var ride here | states: data-open (panel is open or entering); data-closed (panel is closed or animating out (hidden lands after the exit finishes)) | vars: --accordion-panel-height (the measured content height (controller-written) that feeds the accordion-down/up keyframes)
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
- `label:` (string) - required
- `size:` (symbol) - one of default|sm|lg, default "default"
- `src:` (string)
Slots: badge.
- PART `avatar` - Root span (role=img carrying the accessible name) - fallback, image, and badge layer inside it | states: data-size=default|sm|lg (always - the resolved size)
- PART `avatar-fallback` - The initials layer (the content block) - always in the DOM, showing until the image covers it
- PART `avatar-image` - The <img> layered absolutely over the fallback - only when src: is given; a failed load paints nothing
- PART `avatar-badge` - The decorative presence dot (the badge slot), bottom-right
In blocks: `app-shell` - for a screen, start from the block (MCP compose/describe_block, or `bin/rails g poetry:block`), not from scratch.
- RULE: label: (the person's name) is REQUIRED - it is the avatar's accessible name (role=img).
- RULE: The content block is the fallback (initials) and is also required - it is what shows while the image loads or when it fails.
- RULE: The badge slot is decorative (a presence dot); put the status meaning in label:, not in the badge.
- RULE: Stack avatars with poetry_avatar_group; the overflow count is poetry_avatar_group_count.

## badge (`poetry_badge`)

Class: Poetry::Ui::Badge::Component - BEM block `poetry-ui-badge`.
Content block REQUIRED (the visible status text) - a blockless call raises.
- `variant:` (symbol) - one of default|secondary|destructive|outline|success|warning|info, default "default", required
- PART `badge` - The status pill itself (a <span>) - the whole component is this one element | states: data-variant=default|secondary|destructive|outline|success|warning|info (always - the resolved variant)
In blocks: `data-index`, `section-card` - for a screen, start from the block (MCP compose/describe_block, or `bin/rails g poetry:block`), not from scratch.
- RULE: Badges are non-interactive status labels - never attach click handlers; use Button for actions.
- RULE: The visible text is the content block: render ... { "beta" } - there is no label: option.
- RULE: Pick the variant by intent (destructive = error states; success/warning/info = record status, e.g. Fulfilled/Processing/Syncing), never by color preference.
- RULE: Status badges on one surface read as a SET: keep one treatment family per table/list - the soft trio (+ outline for neutral) together, or the solid pair together; never a solid destructive pill inside a soft status column (design lint flags the mix).

## card (`poetry_card`)

Class: Poetry::Ui::Card::Component - BEM block `poetry-ui-card`.
- `title_tag:` (symbol) - one of h1|h2|h3|h4|h5|h6, default "h3"
Slots: title, description, action, footer.
- PART `card` - Root container - the vertical flex stack
- PART `card-header` - The title row grid - gains a trailing auto column when card-action is present
- PART `card-title` - The heading (title_tag, h3 by default)
- PART `card-description` - Muted one-liner under the title
- PART `card-action` - The header's trailing corner control
- PART `card-content` - The body - the content block renders here
- PART `card-footer` - The bottom row (actions/meta)
In blocks: `app-shell`, `section-card`, `stepper` - for a screen, start from the block (MCP compose/describe_block, or `bin/rails g poetry:block`), not from scratch.
- RULE: Compose with the slots (title/description/action/footer) - never rebuild the header grid by hand.
- RULE: The card body is the content block; use CardAction for the header-corner control.
- RULE: The title renders as a real heading (h3 default) - set title_tag: to fit the page outline.

## carousel (`poetry_carousel`)

Class: Poetry::Ui::Carousel::Component - BEM block `poetry-ui-carousel`.
Slot REQUIRED: with_item (at least one slide) - a call without it raises.
- `label:` (string) - required
- `orientation:` (symbol) - one of horizontal|vertical, default "horizontal"
- `show_controls:` (boolean) - default true
Slots: items (many; with_item yields NOTHING to the block - no |param|, write content directly; with_item keywords: classes: ONLY; with_item REQUIRES a content block (the slide)).
- PART `carousel` - The role=region root - the controller (paging, button state, arrow keys) rides here | states: data-orientation=horizontal|vertical (the scroll axis)
- PART `carousel-content` - The viewport - a real scroll-snap container (tabindex=0); the platform owns the physics
- PART `carousel-item` - One role=group slide - sized by item classes (basis-full default)
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
- PART `collapsible` - The disclosure root - the state controller flips the pair here | states: data-open (expanded (server-rendered from open:; the controller flips the pair at runtime)); data-closed (collapsed (the server-rendered default))
- PART `collapsible-trigger` - The disclosure button - mirrors aria-expanded | states: data-panel-open (its content is open (Base UI trigger parity, controller-written; absent while closed))
- PART `collapsible-content` - The disclosure panel - stays in the DOM when closed (hidden) and rides the presence helper on exit | states: data-open (content is open or entering); data-closed (content is closed or animating out (hidden lands after the exit finishes))
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
- `selectable:` ()
- `selection_name:` (string) - default "selected_ids"
Slots: columns (many; with_column REQUIRES a content block (the cell renderer - { |row| ... })).
- PART `data-table` - Root surface - toolbar, table, and pagination footer stack here
- PART `data-table-toolbar` - The row above the table holding the filter form - renders unless filter: false
- PART `data-table-filter` - The GET filter form (role=search) - hidden fields carry the current sort; a new filter resets the page
- PART `table-container` - The composed W1 Table's scroll container - Table renders it, this surface owns where it sits
- PART `data-table-footer` - The Pagination row - renders when total: is more than one page
In blocks: `action-bar` - for a screen, start from the block (MCP compose/describe_block, or `bin/rails g poetry:block`), not from scratch.
- WIRING `poetry--core--table-selection`: targets all; values label; actions press, toggleAll, toggled; events poetry:data-table:selection-change
- RULE: Build State.from_params(params, sortable: [...]) in the controller - NEVER order by raw params; the whitelist is what makes state.order_clause injection-safe.
- RULE: Column cell blocks RETURN the cell content ({ |row| row.title }) - they must not write to the template buffer.
- RULE: Sort/filter/page are URL state over GET links and a GET form. Row mutations (inline edit, row actions) belong to poetry-reactive components rendered inside cells - never to this component.
- RULE: Give the table a caption: - it is the table's accessible purpose.

## empty (`poetry_empty`)

Class: Poetry::Ui::Empty::Component - BEM block `poetry-ui-empty`.
- `media_variant:` (symbol) - one of default|icon, default "default"
- `title_tag:` (symbol) - one of h1|h2|h3|h4|h5|h6, default "h3"
Slots: media, title, description.
- PART `empty` - The empty-state root - the centered header and content stack
- PART `empty-header` - Wrapper around media/title/description - renders when at least one of those slots is set
- PART `empty-icon` - The media slot's box - media_variant: :icon gives the rounded muted icon tile | states: data-variant=default|icon (always - the resolved media_variant)
- PART `empty-title` - The title as a real heading (title_tag, h3 by default)
- PART `empty-description` - Muted copy under the title
- PART `empty-content` - The actions that fix the emptiness - the content block renders here
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
- PART `item` - The row root (a div by default; tag: :a for a clickable row) - variant and density land here as data attributes | states: data-variant=default|outline|muted (the row's visual variant); data-size=default|sm|xs (the row's density)
- PART `item-media` - The leading media cell - sized and rounded by its variant | states: data-variant=default|icon|image (the media treatment)
- PART `item-content` - The center column collecting title, description, and loose content
- PART `item-title` - The title row
- PART `item-description` - The muted description line
- PART `item-actions` - The trailing actions cell
- RULE: Rows live inside poetry_item_group (role=list) and each row passes role: "listitem" - a role=list parent with roleless children fails aria-required-children.
- RULE: Separate grouped rows with poetry_item_separator.
- RULE: Compose with the slots (media/title/description/actions); loose content lands in the content column after the description.
- RULE: media_variant: :icon for a glyph, :image for a thumbnail (sized/rounded automatically).
- RULE: A clickable row is tag: :a with href: - never wrap an Item in a bare <a>.

## metadata_list (`poetry_metadata_list`)

Class: Poetry::Ui::MetadataList::Component - BEM block `poetry-ui-metadata_list`.
Slot REQUIRED: with_item (at least one item (label: plus the value block)) - a call without it raises.
- `columns:` (symbol) - one of one|two|three, default "one"
- `orientation:` (symbol) - one of vertical|horizontal, default "vertical"
Slots: items (many; with_item yields NOTHING to the block - no |param|, write content directly).
- PART `metadata-list` - The <dl> root - the record's fact sheet | states: data-orientation=vertical|horizontal (always - label placement); data-columns=one|two|three (always - the column count word)
- PART `metadata-list-item` - One fact group (a <div> holding its <dt>/<dd> pair)
- PART `metadata-list-label` - The fact's name (<dt>) - muted, small
- PART `metadata-list-value` - The fact's value (<dd>) - composes text, badges, links
- RULE: Record facts on a detail page belong in a MetadataList - never a hand-rolled grid of label/value divs (this is the <dl> the page owes its readers).
- RULE: Each with_item takes label: and the value as its block - values compose freely (text, a Badge, a Link, a Timestamp).
- RULE: columns: :two / :three spread the facts on wide viewports; orientation: :horizontal puts labels beside values (the classic key/value sheet) - pick one per surface.
- RULE: For editable facts pair each value with its edit affordance inside the item block; the list itself stays read-only vocabulary.

## meter (`poetry_meter`)

Class: Poetry::Ui::Meter::Component - BEM block `poetry-ui-meter`.
- `label:` (string) - required
- `max:` (integer) - default 100
- `min:` (integer) - default 0
- `show_value:` (boolean) - default true
- `value:` (integer) - required
- `value_label:` (string)
- PART `meter` - Root (role=meter, aria-value*, and the accessible name); label, readout, and track stack here
- PART `meter-label` - The visible caption span (label:)
- PART `meter-value` - The readout - value_label: verbatim, else the range percentage; renders unless show_value: false
- PART `meter-track` - The full-width rail (Progress's cn chrome)
- PART `meter-indicator` - The filled bar - inline width percentage of the range
- RULE: A quantity within a range is a Meter (disk, seats, strength); an operation's completion over time is Progress. There is NO indeterminate meter - unknown duration means Spinner.
- RULE: label: is REQUIRED - the meter's accessible name and visible caption.
- RULE: value_label: replaces the visible readout verbatim ("3 of 4 seats"); without it the readout shows the percentage of the RANGE. No aria-valuetext - ARIA 1.2 deprecated it on role=meter; aria-valuenow carries the value.

## stat (`poetry_stat`)

Class: Poetry::Ui::Stat::Component - BEM block `poetry-ui-stat`.
Content block REQUIRED (the metric value) - a blockless call raises.
- `delta:` (string)
- `label:` (string) - required
- `sentiment:` (symbol) - one of positive|negative|neutral
- `trend:` (symbol) - one of up|down|flat, default "up"
Slots: description, media.
- PART `stat` - The stat root - a label/value/delta/description column
- PART `stat-label` - The muted metric name above the value
- PART `stat-value` - The metric itself - large, semibold, tabular numerals
- PART `stat-delta` - The change pill beside the value - arrow icon + delta text with an sr-only trend word | states: data-trend=up|down|flat (always - the arrow direction); data-sentiment=positive|negative|neutral (always - resolved sentiment (trend-derived unless overridden))
- PART `stat-description` - Muted supporting copy under the value
- PART `stat-media` - The trend-visual slot (sparkline, chart, glyph) below the text stack
- RULE: One Stat is ONE metric: label: names it, the content block is the value - compose several in a grid (typically each inside a Card) for a dashboard row.
- RULE: delta: carries the change text ('+12.5%'); trend: (up/down/flat) sets the arrow and the default sentiment. Override sentiment: :positive when DOWN is the good direction (costs, churn, error rate) - color follows sentiment, never the arrow.
- RULE: Keep the value textual - tabular numerals are already applied; units and formatting belong in the content ('$45,231', '99.98%').
- RULE: A Stat is not a chart: a trend over time goes in the media slot (or use poetry-charts).

## table (`poetry_table`)

Class: Poetry::Ui::Table::Component - BEM block `poetry-ui-table`.
- PART `table` - The semantic <table> element itself - the root the part helpers compose into
- PART `table-caption` - The <caption> (poetry_table_caption) - the table's accessible purpose
- PART `table-header` - The <thead> (poetry_table_header) holding the column-header row
- PART `table-body` - The <tbody> (poetry_table_body) holding the data rows
- PART `table-footer` - The <tfoot> (poetry_table_footer) - totals/summary rows
- PART `table-row` - A <tr> (poetry_table_row) in any section | states: data-selected (the row is marked selected (presence attribute, no value) - the theme tints it)
- PART `table-head` - A column header <th> (poetry_table_head)
- PART `table-cell` - A data <td> (poetry_table_cell)
In blocks: `data-index` - for a screen, start from the block (MCP compose/describe_block, or `bin/rails g poetry:block`), not from scratch.
- RULE: Compose the table with the part helpers (poetry_table_header/_body/_row/_head/_cell) - they carry the data-slot + classes onto real thead/tbody/tr/th/td.
- RULE: A column header is poetry_table_head (a <th>); a data cell is poetry_table_cell (a <td>).
- RULE: Mark a selected row with data-selected on poetry_table_row - never a bespoke highlight class.

## tag_group (`poetry_tag_group`)

Class: Poetry::Ui::TagGroup::Component - BEM block `poetry-ui-tag_group`.
- `label:` (string) - required
- `name:` (string)
Slots: tags (many; with_tag yields NOTHING to the block - no |param|, write content directly).
- PART `tag-group` - The labelled wrapper - caption span + grid stack here
- PART `tag-group-label` - The caption span (label:), wired via aria-labelledby (a grid is not a labelable form control - never a <label>)
- PART `tag-group-grid` - The tag collection (role=grid; role=group + the tab stop when empty) - roving focus, removal keys, and the focus-scoped live region ride here | states: data-empty (no tags remain (controller-kept after removals))
- PART `tag-group-tag` - One chip (role=row > gridcell): content, the remove button, and - in form mode - the hidden name[] input | states: data-disabled (the tag is disabled (skipped by arrows and removal)); data-value (always - the tag's value (the remove event's detail and the hidden input's value))
- PART `tag-group-remove` - The per-tag remove button - tabbable (Tab steps from the row into it), removes exactly its own tag
- WIRING `poetry--core--roving-focus`: values loop, manageTabindex, orientation; actions keydown; events poetry--core--roving-focus:entry
- WIRING `poetry--core--tag-group`: actions keydown, remove; events poetry:tag-group:remove
- RULE: Removable chips are a TagGroup - never hand-rolled badges with x buttons; removal keyboard (Delete/Backspace), focus recovery, and the live region ride the controller.
- RULE: label: is REQUIRED (the grid's accessible name, rendered as a caption span).
- RULE: name: turns the group into a form value - one hidden <name>[] input per tag submits; removing a tag removes its input.
- RULE: Removal is cancelable: listen for poetry:tag-group:remove and preventDefault to own the removal server-side (Turbo re-render).
- RULE: Choosing from options is Combobox multiple; toggling fixed choices is ToggleGroup - a TagGroup holds items that exist until removed.

## toolbar (`poetry_toolbar`)

Class: Poetry::Ui::Toolbar::Component - BEM block `poetry-ui-toolbar`.
Slot REQUIRED: with_button (at least one control (with_button / with_input)) - a call without it raises.
- `orientation:` (symbol) - one of horizontal|vertical, default "horizontal"
- `label:` (string) - required
- `loop:` (boolean) - default true
Slots: items (many; types button|input|separator - one with_<type> setter each, options as keywords).
- PART `toolbar` - The role=toolbar root - one Tab stop; arrow keys rove across the slotted controls (roving-focus, with the caret guard protecting inputs) | states: data-orientation=horizontal|vertical (always - which arrows rove)
- WIRING `poetry--core--roving-focus`: values loop, manageTabindex, orientation; actions keydown; events poetry--core--roving-focus:entry
- RULE: A Toolbar is ONE Tab stop: arrows move between its controls - use it for grouped actions over a surface (table bulk actions, editor strips), never as page navigation.
- RULE: Compose through the typed slots: with_button (a real poetry Button - tag: :a makes it a link), with_input (search/filter - the caret keeps its arrow keys), with_separator (orientation flips automatically).
- RULE: label: is the toolbar's accessible name and is required - screen readers announce it on entry.
- RULE: A ToggleGroup composed inside keeps its own arrow navigation (its items rove locally); place it between separators so the seam reads as a group.

## tree (`poetry_tree`)

Class: Poetry::Ui::Tree::Component - BEM block `poetry-ui-tree`.
- `label:` (string) - required
- PART `tree` - The treegrid container (role=treegrid, the accessible name) - roving focus, expansion keys, and typeahead ride here; rows are FLAT siblings
- PART `tree-item` - One row (role=row > gridcell) - hierarchy in aria-level/posinset/setsize, indentation via --poetry-tree-level; rows under a collapsed ancestor render hidden | states: data-expanded (the row's subtree is open (parents only; aria-expanded is the canonical twin)); data-disabled (the item is disabled (skipped by arrows and typeahead)); data-value (always - the toggle event's identity); data-level (always - the 1-based depth (aria-level's twin; --poetry-tree-level drives the indent)) | vars: --poetry-tree-level (the 1-based depth - indentation is calc((level - 1) * step) in the dictionary)
- PART `tree-item-toggle` - The chevron (parents only): tabindex -1, never steals focus, aria-label flips Expand/Collapse | states: data-expand-label (always - the localized Expand string the controller swaps in on collapse); data-collapse-label (always - the localized Collapse string the controller swaps in on expand)
- PART `tree-item-label` - The row's text - a link when href: is given
- WIRING `poetry--core--tree`: actions keydown, press, pressStart, toggle; events poetry:tree:toggle
- RULE: Hierarchical expandable lists are a Tree - never hand-rolled nested <ul>s with click handlers; the treegrid semantics, expansion keys, and focus rules ride the controller.
- RULE: label: is REQUIRED (the treegrid's accessible name).
- RULE: Items: tree.with_item(text:, value:, expanded:, disabled:, href:) with nesting via the block - the component flattens and computes aria-level/posinset/setsize.
- RULE: Expansion is client state; persist it by listening for poetry:tree:toggle and re-rendering with expanded: from your store.
- RULE: Navigation destinations take href: (the label renders as a link); a Tree is not a menu - actions belong to DropdownMenu, picking to Select/Combobox.

