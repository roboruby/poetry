# poetry foundations components

Contracts generated from the registry. `RULE` lines are constraints,
not suggestions. Options are keywords; content is the block.

## icon (`poetry_icon`)

Class: Poetry::Ui::Icon::Component - BEM block `poetry-ui-icon`.
- `label:` (string)
- `library:` (symbol)
- `name:` (symbol) - required, format: icon-name
- RULE: Icons are decorative by default (aria-hidden); pass label: when the icon stands alone.
- RULE: Never inline raw <svg> markup where an icon exists - use poetry_icon.

## kbd (`poetry_kbd`)

Class: Poetry::Ui::Kbd::Component - BEM block `poetry-ui-kbd`.
Content block REQUIRED (the key text) - a blockless call raises.
- RULE: Kbd renders a real <kbd> - the key text is the content block (⌘, Esc, Ctrl).
- RULE: For a chord (⌘+K) render one Kbd per key inside an inline-flex row.

## link (`poetry_link`)

Class: Poetry::Ui::Link::Component - BEM block `poetry-ui-link`.
- `underline:` (symbol) - one of hover|always|none, default "hover"
- `current:` (boolean) - default false
- `external:` (boolean) - default false
- `href:` (string) - required
- RULE: Use poetry_link for navigation - poetry_button for actions (never an <a> styled by hand).
- RULE: Mark the active nav item with current: true (aria-current), never with a bespoke class.
- RULE: external: true handles target/rel safely - never hand-write target=_blank.

## marker (`poetry_marker`)

Class: Poetry::Ui::Marker::Component - BEM block `poetry-ui-marker`.
- `variant:` (symbol) - one of default|separator|border, default "default", required
- `announce:` (symbol) - one of none|status, default "none"
- `tag:` (symbol) - default "div"
Slots: icon (takes poetry_icon props, not a block).
- RULE: The marker text is real announced content - never mark it aria-hidden or role=separator.
- RULE: announce: :status is for the ONE in-flight marker (streaming status); static dividers never announce.
- RULE: Icons in markers ride the typed icon slot (decorative always).
- RULE: Use variant: :separator for date/section breaks; :border under pinned headers.

## separator (`poetry_separator`)

Class: Poetry::Ui::Separator::Component - BEM block `poetry-ui-separator`.
- `decorative:` (boolean) - default true
- `orientation:` (symbol) - one of horizontal|vertical, default "horizontal"
- RULE: A purely visual divider stays decorative (the default): aria-hidden, role absent.
- RULE: Set decorative: false only when the divide is semantically meaningful (role=separator).

