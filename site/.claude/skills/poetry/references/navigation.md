# poetry navigation components

Contracts generated from the registry. `RULE` lines are constraints,
not suggestions. Options are keywords; content is the block.

## breadcrumb (`poetry_breadcrumb`)

Class: Poetry::Ui::Breadcrumb::Component - BEM block `poetry-ui-breadcrumb`.
Slots: items (many).
- RULE: Declare the trail with with_item(label, href:) - never hand-build the nav/ol/li chain.
- RULE: The current page is the item WITHOUT href: (it renders aria-current=page, not a link).
- RULE: Collapse a long middle with with_ellipsis - it announces 'More' to screen readers.

## navigation_menu (`poetry_navigation_menu`)

Class: Poetry::Ui::NavigationMenu::Component - BEM block `poetry-ui-navigation_menu`.
- `label:` (string)
- `viewport:` (boolean) - default false
Slots: items (many; with_item yields NOTHING to the block - no |param|, write content directly).
- WIRING `poetry--core--navigation-menu`: values closeDelay, openDelay; actions cancelClose, focusLeft, keydown, scheduleClose, scheduleOpen, toggle
- WIRING `poetry--core--popper`: targets anchor, arrow, content; values align, alignOffset, anchor, anchorPoint, avoidCollisions, side, sideOffset, strategy; actions anchorPointValueChanged, reposition, setAnchor, setAnchorElement
- RULE: label: is REQUIRED (the nav landmark's accessible name).
- RULE: with_item(title, value:) declares a trigger + panel; with_link(title, href:) is a top-level destination - use links for pages, panels for groups of links.
- RULE: Panel content is poetry_navigation_menu_link entries (active: marks the current page) - never buttons; navigation navigates.
- RULE: This is a DISCLOSURE bar: Tab moves through it normally and nothing traps - do not wire menu/menuitem roles.
- RULE: Rich panels (title + description grids) want viewport: true - the shared morphing card contains and sizes them; the default per-item mode suits simple link lists (the top-nav block shows the viewport pattern).

## pagination (`poetry_pagination`)

Class: Poetry::Ui::Pagination::Component - BEM block `poetry-ui-pagination`.
- `current:` (integer) - required
- `current_variant:` (symbol) - one of outline|filled, default "outline"
- `label:` (string) - default "pagination"
- `next_label:` (string) - default "Next"
- `previous_label:` (string) - default "Previous"
- `siblings:` (integer) - default 1
- `total:` (integer) - required
- RULE: poetry_pagination(current:, total:, path:) - never hand-build the <nav>/<ul>/<li> list.
- RULE: path: is a callable ->(page) { url } (e.g. ->(p) { products_path(page: p) }).
- RULE: The current page is aria-current=page; current_variant: :outline (upstream parity, default) or :filled (the primary treatment - unambiguous active state); the rest are ghost links.

## sidebar (`poetry_sidebar`)

Class: Poetry::Ui::Sidebar::Component - BEM block `poetry-ui-sidebar`.
- `collapsible:` (symbol) - one of offcanvas|icon|none, default "offcanvas"
- `open:` (boolean) - default true
- `side:` (symbol) - one of left|right, default "left"
- `variant:` (symbol) - one of sidebar|floating|inset, default "sidebar"
Slots: nav, inset.
- WIRING `poetry--core--sidebar`: targets inner, mobileDialog, mobileInner, sidebar; values collapsible, cookieMaxAge, cookieName, open, shortcut; actions close, closeMobile, mobileBackdropClose, open, toggle; events poetry--core--sidebar:mobile-toggle, poetry--core--sidebar:toggle
- RULE: Wrap the WHOLE shell: with_nav is the sidebar column, with_inset is the page area (the trigger lives in the inset).
- RULE: Read the persisted state server-side - open: cookies[:sidebar_state] != "false" - so the first paint has no collapse flash.
- RULE: collapsible: :icon keeps icon rails visible when collapsed; :offcanvas slides it fully away; :none is a static column.
- RULE: Menu entries are poetry_sidebar_menu_button(href:) links (active: marks the current route) - navigation navigates.

## tabs (`poetry_tabs`)

Class: Poetry::Ui::Tabs::Component - BEM block `poetry-ui-tabs`.
- `default:` (string)
- `label:` (string)
- `orientation:` (symbol) - one of horizontal|vertical, default "horizontal"
- `variant:` (symbol) - one of default|line, default "default"
Slots: tabs (many; with_tab yields NOTHING to the block - no |param|, write content directly).
- WIRING `poetry--core--roving-focus`: values loop, manageTabindex, orientation; actions keydown; events poetry--core--roving-focus:entry
- WIRING `poetry--core--tabs`: values activateOnFocus; actions activate, focusActivate, setValue; events poetry--core--tabs:change
- RULE: Declare tabs with with_tab(title, value:) + the panel block (or defer: for a lazy turbo-frame panel) - never hand-wire role=tab/tabpanel ids.
- RULE: default: picks the server-rendered active tab (the first enabled tab otherwise) - the panel is visible without JS.
- RULE: label: names the tablist (aria-label) - recommended whenever the page has several tab sets.
- RULE: Tabs switch VIEWS of one context; use navigation (links) when the URL should change.

