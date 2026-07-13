# poetry foundations components

Contracts generated from the registry. `RULE` lines are constraints,
not suggestions. Options are keywords; content is the block.

## icon (`poetry_icon`)

Class: Poetry::Ui::Icon::Component - BEM block `poetry-ui-icon`.
- `label:` (string)
- `library:` (symbol)
- `name:` (symbol) - required, format: icon-name
- PART `icon` - The <svg> root itself - the vendored icon markup renders inside; ARIA (label: vs decorative) rides here
In blocks: `app-shell`, `data-index`, `destructive-panel`, `page-header`, `section-card`, `stepper`, `top-nav` - for a screen, start from the block (MCP compose/describe_block, or `bin/rails g poetry:block`), not from scratch.
- RULE: Icons are decorative by default (aria-hidden); pass label: when the icon stands alone.
- RULE: Never inline raw <svg> markup where an icon exists - use poetry_icon.

## kbd (`poetry_kbd`)

Class: Poetry::Ui::Kbd::Component - BEM block `poetry-ui-kbd`.
Content block REQUIRED (the key text) - a blockless call raises.
- PART `kbd` - The <kbd> element itself - the key text renders here
- RULE: Kbd renders a real <kbd> - the key text is the content block (⌘, Esc, Ctrl).
- RULE: For a chord (⌘+K) render one Kbd per key inside an inline-flex row.

## link (`poetry_link`)

Class: Poetry::Ui::Link::Component - BEM block `poetry-ui-link`.
- `underline:` (symbol) - one of hover|always|none, default "hover"
- `current:` (boolean) - default false
- `external:` (boolean) - default false
- `href:` (string) - required
- PART `link` - The rendered <a> - the whole component; current: marks it aria-current=page
In blocks: `section-card`, `top-nav` - for a screen, start from the block (MCP compose/describe_block, or `bin/rails g poetry:block`), not from scratch.
- RULE: Use poetry_link for navigation - poetry_button for actions (never an <a> styled by hand).
- RULE: Mark the active nav item with current: true (aria-current), never with a bespoke class.
- RULE: external: true handles target/rel safely - never hand-write target=_blank.

## marker (`poetry_marker`)

Class: Poetry::Ui::Marker::Component - BEM block `poetry-ui-marker`.
- `variant:` (symbol) - one of default|separator|border, default "default", required
- `announce:` (symbol) - one of none|status, default "none"
- `tag:` (symbol) - default "div"
Slots: icon (takes poetry_icon props, not a block).
- PART `marker` - The divider/status root - the label is real announced content (role=status when announce: :status; never role=separator) | states: data-variant=default|separator|border (always - the resolved variant)
- PART `marker-icon` - Decorative icon wrapper (aria-hidden always)
- PART `marker-content` - The label span - the marker text itself
- RULE: The marker text is real announced content - never mark it aria-hidden or role=separator.
- RULE: announce: :status is for the ONE in-flight marker (streaming status); static dividers never announce.
- RULE: Icons in markers ride the typed icon slot (decorative always).
- RULE: Use variant: :separator for date/section breaks; :border under pinned headers.

## separator (`poetry_separator`)

Class: Poetry::Ui::Separator::Component - BEM block `poetry-ui-separator`.
- `decorative:` (boolean) - default true
- `orientation:` (symbol) - one of horizontal|vertical, default "horizontal"
- PART `separator` - The divider itself - decorative (aria-hidden) by default, role=separator when decorative: false | states: data-orientation=horizontal|vertical (always - the resolved orientation)
In blocks: `app-shell`, `page-header` - for a screen, start from the block (MCP compose/describe_block, or `bin/rails g poetry:block`), not from scratch.
- RULE: A purely visual divider stays decorative (the default): aria-hidden, role absent.
- RULE: Set decorative: false only when the divide is semantically meaningful (role=separator).

