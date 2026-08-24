# poetry foundations components

Contracts generated from the registry. `RULE` lines are constraints,
not suggestions. Options are keywords; content is the block.

## icon (`poetry_icon`)

Renders an inline SVG icon from the icon set.

Class: Poetry::Ui::Icon::Component - BEM block `poetry-ui-icon`.
- `label:` (string) - The accessible name - given, the icon is standalone (role=img); absent, it is decorative (aria-hidden).
- `library:` (symbol) - Per-render icon set override (defaults to config.icon_library).
- `name:` (symbol) - required, format: icon-name - The icon's name in the active set. format: :"icon-name" is the machine-readable value contract: the registry carries it, and literal names are validated against the icon set statically - a misspelled name is caught before it can crash a render.
- PART `icon` - The <svg> root itself - the vendored icon markup renders inside; ARIA (label: vs decorative) rides here
In blocks: `action-bar`, `app-shell`, `data-index`, `destructive-panel`, `page-header`, `section-card`, `stepper`, `top-nav` - for a screen, start from the block (MCP compose/describe_block, or `bin/rails g poetry:block`), not from scratch.
- RULE: Icons are decorative by default (aria-hidden); pass label: when the icon stands alone.
- RULE: Never inline raw <svg> markup where an icon exists - use poetry_icon.

## kbd (`poetry_kbd`)

Displays a keyboard key or shortcut.

Class: Poetry::Ui::Kbd::Component - BEM block `poetry-ui-kbd`.
Content block REQUIRED (the key text) - a blockless call raises.
- PART `kbd` - The <kbd> element itself - the key text renders here
- RULE: Kbd renders a real <kbd> - the key text is the content block (⌘, Esc, Ctrl).
- RULE: For a chord (⌘+K) render one Kbd per key inside an inline-flex row.

## link (`poetry_link`)

A styled navigational hyperlink.

Class: Poetry::Ui::Link::Component - BEM block `poetry-ui-link`.
Content block REQUIRED (the visible link text) - a blockless call raises.
- `underline:` (symbol) - one of hover|always|none, default "hover" - When the underline appears; :none suits links styled by their container.
- `current:` (boolean) - default false - Marks this link as the current page via aria-current=page.
- `external:` (boolean) - default false - Opens in a new tab with rel="noopener noreferrer" - never hand-write target=_blank.
- `href:` (string) - required - The destination URL.
- PART `link` - The rendered <a> - the whole component; current: marks it aria-current=page
In blocks: `section-card`, `top-nav` - for a screen, start from the block (MCP compose/describe_block, or `bin/rails g poetry:block`), not from scratch.
- RULE: Use poetry_link for navigation - poetry_button for actions (never an <a> styled by hand).
- RULE: Mark the active nav item with current: true (aria-current), never with a bespoke class.
- RULE: external: true handles target/rel safely - never hand-write target=_blank.

## marker (`poetry_marker`)

A transcript divider or inline status marker for chat UIs.

Class: Poetry::Ui::Marker::Component - BEM block `poetry-ui-marker`.
Content block REQUIRED (the marker label) - a blockless call raises.
- `variant:` (symbol) - one of default|separator|border, default "default", required - The divider treatment - :separator for date/section breaks, :border for a full-width rule under pinned headers.
- `announce:` (symbol) - one of none|status, default "none" - Makes the marker a live status region (role=status) for the one in-flight marker; static dividers never announce.
- `tag:` (symbol) - default "div" - The root element's tag.
Slots: icon (Optional leading visual: name: renders an icon glyph; a block carries other media (a Spinner mid-run). Either way it sits in an aria-hidden cell and stays decorative - the marker root does the announcing.; with_icon yields NOTHING to the block - no |param|, write content directly).
- PART `marker` - The divider/status root - the label is real announced content (role=status when announce: :status; never role=separator) | states: data-variant=default|separator|border (always - the resolved variant)
- PART `marker-icon` - Decorative icon wrapper (aria-hidden always)
- PART `marker-content` - The label span - the marker text itself
- RULE: The marker text is real announced content - never mark it aria-hidden or role=separator.
- RULE: announce: :status is for the ONE in-flight marker (streaming status); static dividers never announce.
- RULE: Icons ride the icon slot (decorative always): with_icon(name:) for a lucide glyph, with_icon { } for other media (a Spinner mid-run).
- RULE: Use variant: :separator for date/section breaks; :border under pinned headers.

## separator (`poetry_separator`)

A thin divider between content, decorative or semantic.

Class: Poetry::Ui::Separator::Component - BEM block `poetry-ui-separator`.
- `decorative:` (boolean) - default true - Whether the divide is purely visual (aria-hidden) or a semantic boundary (role=separator).
- `orientation:` (symbol) - one of horizontal|vertical, default "horizontal" - The divider's axis.
- PART `separator` - The divider itself - decorative (aria-hidden) by default, role=separator when decorative: false | states: data-orientation=horizontal|vertical (always - the resolved orientation)
In blocks: `app-shell`, `page-header` - for a screen, start from the block (MCP compose/describe_block, or `bin/rails g poetry:block`), not from scratch.
- RULE: A purely visual divider stays decorative (the default): aria-hidden, role absent.
- RULE: Set decorative: false only when the divide is semantically meaningful (role=separator).

