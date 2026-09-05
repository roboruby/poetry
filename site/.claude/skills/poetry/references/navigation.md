# poetry navigation components

Contracts generated from the registry. `RULE` lines are constraints,
not suggestions. Options are keywords; content is the block.

## breadcrumb (`poetry_breadcrumb`)

Shows the path to the current page as a trail of links.

Class: Poetry::Ui::Breadcrumb::Component - BEM block `poetry-ui-breadcrumb`.
Slot REQUIRED: with_item (at least one item) - a call without it raises.
Slots: items (The crumbs, in declaration order. A label with href: renders a link; without one, the current page. A block makes the <li>'s content caller-owned (a dropdown crumb, a custom-rendered link).; many; with_item yields NOTHING to the block - no |param|, write content directly), separator (Replaces the separator glyph in EVERY gap: an icon name, or a block for arbitrary content. Absent, the default chevron renders (with its RTL flip - a custom glyph is used as given).; with_separator yields NOTHING to the block - no |param|, write content directly; with_separator keywords: icon: ONLY).
- PART `breadcrumb` - The <nav> landmark (aria-label=breadcrumb) around the trail
- PART `breadcrumb-list` - The <ol> laying crumbs and separators out as one wrapping row
- PART `breadcrumb-item` - One <li> of the trail - wraps a link, the current page, the ellipsis, or a block item's own content (a dropdown crumb, a custom link)
- PART `breadcrumb-link` - A crumb with href: - a real <a> to an ancestor page
- PART `breadcrumb-page` - The current page (the item without href:) - aria-current=page, not a link
- PART `breadcrumb-separator` - The chevron <li> between crumbs - presentational, aria-hidden
- PART `breadcrumb-ellipsis` - The collapsed-middle glyph (with_ellipsis) - aria-hidden; a sibling sr-only 'More' announces it
In blocks: `app-shell`, `page-header` - for a screen, start from the block (MCP compose/describe_block, or `bin/rails g poetry:block`), not from scratch.
- RULE: Declare the trail with with_item(label, href:) - never hand-build the nav/ol/li chain.
- RULE: The current page is the item WITHOUT href: (it renders aria-current=page, not a link).
- RULE: Collapse a long middle with with_ellipsis - it announces 'More' to screen readers.
- RULE: A BLOCK item (with_item { ... }) renders your content inside the <li> - the seat for a dropdown crumb or a custom-rendered link; you own its semantics (aria-current only applies to label items).
- RULE: with_separator(icon: :dot) - or a block - replaces the chevron in EVERY gap; the default chevron RTL-flips, a custom glyph is used as given.

## navigation_menu (`poetry_navigation_menu`)

A site-navigation bar with links and optional dropdown panels.

Class: Poetry::Ui::NavigationMenu::Component - BEM block `poetry-ui-navigation_menu`.
- `label:` (string) - required - The nav landmark's accessible name - a page may hold more than one nav.
- `viewport:` (boolean) - default false - Opts into the shared morphing viewport: panels adopt into one positioned card that morphs size and position between triggers. Off, each panel opens under its own item (also the no-JS shape).
Slots: items (The bar entries. with_item(title, value:) { panel } declares a trigger + panel; with_item(title, href:) a top-level link (with_link is the shorthand).; many; with_item yields NOTHING to the block - no |param|, write content directly).
- PART `navigation-menu` - The <nav> landmark around the whole disclosure bar | states: data-viewport (the mode marker ("true" = shared morphing viewport, "false" = per-item panels) - the dictionary's group-data chrome keys on it)
- PART `navigation-menu-list` - The bar row holding every item
- PART `navigation-menu-item` - One bar entry - wraps a trigger + panel pair or a top-level link | states: data-value (the entry's value - the controller's open/close key)
- PART `navigation-menu-trigger` - The disclosure button opening its panel | states: data-popup-open (its panel is open (written with aria-expanded - the chevron rotation hook)); data-open (its panel is open (the controller writes both vocabularies)); data-closed (its panel is closed (written after the first close))
- PART `navigation-menu-content` - One item's panel - presence-animated; in viewport mode it is adopted into the shared viewport on first activation | states: data-open (panel is open (presence flips the pair at runtime)); data-closed (panel is closed or animating out (the server-rendered state)); data-activation-direction (which way the activation traveled between triggers (left/right, viewport mode) - keys the slide styles); data-viewport-panel (stamped once the panel is adopted into the shared viewport)
- PART `navigation-menu-positioner` - The viewport-mode shell popper positions against the active trigger | states: data-instant (suppresses the morph transitions for one painted frame (cold opens)) | vars: --positioner-width (the pinned morph width (reset to auto once the transition settles)); --positioner-height (the pinned morph height (reset to auto once the transition settles))
- PART `navigation-menu-popup` - The morphing card inside the positioner - open state and the size transition ride here | states: data-open (a panel is showing (the controller flips the pair)); data-closed (the popup is closed (the server-rendered state)); data-instant (suppresses the morph transitions for one painted frame (cold opens)); data-starting-style (the enter transition's first frame (the presence module's two-frame trick)); data-ending-style (held through the exit transition before the popup hides) | vars: --popup-width (the pinned morph width (reset to auto once the transition settles)); --popup-height (the pinned morph height (reset to auto once the transition settles))
- PART `navigation-menu-viewport` - The adoption container inside the popup - adopted panels stack absolutely in it
- PART `navigation-menu-link` - A REAL destination link - top-level (with_link) or a panel entry (poetry_navigation_menu_link) | states: data-active (the current page (active: true))
In blocks: `top-nav` - for a screen, start from the block (MCP compose/describe_block, or `bin/rails g poetry:block`), not from scratch.
- WIRING root: `poetry--core--navigation-menu` registers; actions keydown on keydown, focusLeft on focusout | `poetry--core--popper` (if viewport) registers; values side, align, side_offset, strategy
- WIRING item: `poetry--core--navigation-menu` actions scheduleOpen on pointerenter, scheduleClose on pointerleave
- WIRING trigger: `poetry--core--navigation-menu` actions toggle on click
- WIRING positioner: `poetry--core--popper` targets content | `poetry--core--navigation-menu` actions cancelClose on pointerenter, scheduleClose on pointerleave
- RULE: label: is REQUIRED (the nav landmark's accessible name).
- RULE: with_item(title, value:) declares a trigger + panel; with_link(title, href:) is a top-level destination - use links for pages, panels for groups of links.
- RULE: Panel content is poetry_navigation_menu_link entries (active: marks the current page) - never buttons; navigation navigates.
- RULE: This is a DISCLOSURE bar: Tab moves through it normally and nothing traps - do not wire menu/menuitem roles.
- RULE: Rich panels (title + description grids) want viewport: true - the shared morphing card contains and sizes them; the default per-item mode suits simple link lists (the top-nav block shows the viewport pattern).

## pagination (`poetry_pagination`)

Navigation for moving between pages of content.

Class: Poetry::Ui::Pagination::Component - BEM block `poetry-ui-pagination`.
- `current:` (integer) - required - The current page number (1-based).
- `current_variant:` (symbol) - one of outline|filled, default "outline" - How the current page link renders: :outline, or :filled for the primary Button treatment (an unambiguous active state).
- `edges:` (symbol) - one of labeled|icons|none, default "labeled" - The Previous/Next treatment: :labeled (chevron + responsive text), :icons (chevron only - table footers), :none (no edge links).
- `label:` (string) - default "pagination" - The nav landmark's accessible name.
- `next_label:` (string) - default "Next" - The Next link's visible text (hidden on narrow viewports).
- `pages:` (boolean) - default true - Set false to drop the numbered links - the compact two-button pager (pair with edges: :icons).
- `previous_label:` (string) - default "Previous" - The Previous link's visible text (hidden on narrow viewports).
- `siblings:` (integer) - default 1 - How many page links flank the current page before gaps elide to ellipses.
- `total:` (integer) - required - The total page count.
- PART `pagination` - The <nav> landmark (role=navigation, aria-label) around the page list
- PART `pagination-content` - The <ul> holding every entry as one horizontal row
- PART `pagination-item` - One <li> per entry - previous/next, a page link, or a gap
- PART `pagination-ellipsis` - The elided-pages marker between windows - aria-hidden with an sr-only 'More pages'
In blocks: `data-index` - for a screen, start from the block (MCP compose/describe_block, or `bin/rails g poetry:block`), not from scratch.
- RULE: poetry_pagination(current:, total:, path:) - never hand-build the <nav>/<ul>/<li> list.
- RULE: path: is a callable ->(page) { url } (e.g. ->(p) { products_path(page: p) }).
- RULE: The current page is aria-current=page; current_variant: :outline (the default) or :filled (the primary treatment - unambiguous active state); the rest are ghost links.
- RULE: edges: :icons renders chevron-only Previous/Next (the table-footer posture); :none drops them for a bare page list; pages: false drops the numbers (pair with edges: :icons for the compact pager).
- RULE: Host paginates with kaminari, pagy (v43+), or will_paginate? Run bin/rails g poetry:pagination (no argument = detect and install an adapter for each loaded gem) and keep calling paginate / poetry_pagy_nav / will_paginate(renderer: PoetryLinkRenderer) - never hand-wire poetry_pagination around a paginator gem.

## sidebar (`poetry_sidebar`)

A collapsible app-shell navigation column.

Class: Poetry::Ui::Sidebar::Component - BEM block `poetry-ui-sidebar`.
Slot REQUIRED: with_nav (the sidebar column) - a call without it raises.
- `collapsible:` (symbol) - one of offcanvas|icon|none, default "offcanvas" - What collapsing does: slide fully away, shrink to an icon rail, or :none for a static column.
- `open:` (boolean) - default true - The expanded/collapsed state at first paint - feed it from the persisted cookie so there is no collapse flash.
- `side:` (symbol) - one of left|right, default "left" - Which edge the column hangs on.
- `variant:` (symbol) - one of sidebar|floating|inset, default "sidebar" - The column treatment: flush column, floating card, or inset panel.
Slots: nav (The sidebar column's content (required) - groups, menus, header/footer.), inset (The page area beside the column - rendered as the <main> inset.).
- PART `sidebar-wrapper` - The provider shell around the column, the mobile dialog, and the inset | vars: --sidebar-width (the expanded column width (16rem) - the gap/container geometry reads it); --sidebar-width-icon (the collapsed icon-rail width (3rem))
- PART `sidebar` - The desktop state peer - the collapse state lives here and the pure-CSS group-data chrome keys on it | states: data-state (expanded or collapsed - the controller flips it and persists the cookie); data-collapsible=offcanvas|icon|none (the collapse mode WHILE collapsed (empty while expanded - source parity)); data-variant=sidebar|floating|inset (the column treatment); data-side=left|right (which edge the column hangs on)
- PART `sidebar-gap` - The in-flow width ghost that pushes the inset over - its width animates on collapse
- PART `sidebar-container` - The fixed-position column itself | states: data-side=left|right (which edge it pins to)
- PART `sidebar-inner` - The flex column receiving the nav slot - the mobile mode adopts its children from here
- PART `sidebar-mobile` - The mobile sheet <dialog> (below md) - server-rendered empty; the controller adopts the nav children on open | states: data-open (sheet is open (presence flips the pair at runtime)); data-closed (sheet is closed (the server-rendered state)); data-mobile (always "true" - the mobile-mode marker); data-side=left|right (which edge the sheet slides from); data-sidebar (always "sidebar" - the suite-wide sub-part marker) | vars: --sidebar-width (overridden inline to the mobile sheet width (18rem))
- PART `sidebar-mobile-inner` - The adoption container the nav children move into while the sheet is open
- PART `sidebar-inset` - The <main> page area beside the column
- PART `sidebar-header` - Top block of the column (with_nav content)
- PART `sidebar-footer` - Bottom block of the column
- PART `sidebar-content` - The scrollable middle of the column
- PART `sidebar-group` - One titled section inside the content
- PART `sidebar-group-label` - The section heading - fades and collapses away in icon mode
- PART `sidebar-menu` - The <ul> of menu items inside a group
- PART `sidebar-menu-item` - One <li> menu row (the group/menu-item hover scope)
- PART `sidebar-menu-button` - The row's link (href:) or button - the navigation entry itself | states: data-active (the current route (active: - links also get aria-current=page)); data-open (when the button is a collapsible's trigger - the disclosure state the collapsible controller flips); data-size (the row size variant (default, sm, or lg) - the action/badge tops key on it); data-variant=default|outline (always - the treatment)
- PART `sidebar-menu-action` - The item-corner action button, absolutely positioned in the row | states: data-sidebar (always "menu-action" - the suite-wide sub-part marker)
- PART `sidebar-menu-badge` - The trailing count/status chrome in the row corner - pointer-transparent | states: data-sidebar (always "menu-badge" - the suite-wide sub-part marker)
In blocks: `app-shell` - for a screen, start from the block (MCP compose/describe_block, or `bin/rails g poetry:block`), not from scratch.
- WIRING root: `poetry--core--sidebar` registers; values open, collapsible
- WIRING peer: `poetry--core--sidebar` targets sidebar
- WIRING inner: `poetry--core--sidebar` targets inner
- WIRING mobile: `poetry--core--sidebar` actions closeMobile on cancel, mobileBackdropClose on click; targets mobileDialog
- WIRING mobile_inner: `poetry--core--sidebar` targets mobileInner
- WIRING trigger: `poetry--core--sidebar` actions toggle on click
- RULE: Wrap the WHOLE shell: with_nav is the sidebar column, with_inset is the page area (the trigger lives in the inset).
- RULE: Read the persisted state server-side - open: cookies[:sidebar_state] != "false" - so the first paint has no collapse flash.
- RULE: collapsible: :icon keeps icon rails visible when collapsed; :offcanvas slides it fully away; :none is a static column.
- RULE: Menu entries are poetry_sidebar_menu_button(href:) links (active: marks the current route) - navigation navigates.

## tabs (`poetry_tabs`)

A tablist of triggers that switch between content panels.

Class: Poetry::Ui::Tabs::Component - BEM block `poetry-ui-tabs`.
Slot REQUIRED: with_tab (at least one tab) - a call without it raises.
- `default:` (string) - The value of the server-rendered active tab; defaults to the first enabled tab. Raises when it matches no tab.
- `label:` (string) - The tablist's accessible name - recommended when a page has several tab sets.
- `orientation:` (symbol) - one of horizontal|vertical, default "horizontal" - The tab axis; :vertical stacks the triggers and flips the arrow keys.
- `variant:` (symbol) - one of default|line, default "default" - The list's visual treatment: :default a filled capsule, :line an underline indicator.
Slots: tabs (Declares one tab: the title, its value:, and the panel as the block (defer: swaps in a lazy turbo-frame panel; panel: false declares a list-only tab). Omitting all three raises.; many; with_tab yields NOTHING to the block - no |param|, write content directly).
- PART `tabs` - Root wrapper - the orientation rides here and flips the flex direction | states: data-orientation=horizontal|vertical (the tab axis (matches aria-orientation on the list))
- PART `tabs-list` - The role=tablist row of triggers - the roving-focus keyboard group and the visual variant ride here | states: data-variant (the list treatment - default (filled capsule) or line (underline indicator))
- PART `tabs-trigger` - One role=tab button per tab | states: data-active (the selected tab (the controller moves it with aria-selected on activation)); data-disabled (tab is disabled - also filters it from the roving-focus collection); data-value (the tab's value - the key the controller matches panels against)
- PART `tabs-content` - One role=tabpanel per tab - only the active panel is visible | states: data-hidden (panel is inactive (paired with the hidden property - the controller flips both)); data-value (the owning tab's value)
- WIRING root: `poetry--core--tabs` registers
- WIRING list: `poetry--core--roving-focus` registers; values orientation, loop; actions keydown on keydown | `poetry--core--tabs` actions focusActivate on poetry--core--roving-focus:entry
- WIRING trigger: `poetry--core--tabs` actions activate on click
- tool set_value (mutating; params: value (string, required)) - Activate the tab whose value matches and show its panel. [opt in with webmcp: "name" on the call; dispatches poetry--core--tabs#setValue]
- RULE: Declare tabs with with_tab(title, value:) + the panel block (or defer: for a lazy turbo-frame panel) - never hand-wire role=tab/tabpanel ids.
- RULE: panel: false declares a list-only tab (no tabpanel renders, the trigger drops aria-controls) - for demos/pattern shells; real tab sets carry panels.
- RULE: default: picks the server-rendered active tab (the first enabled tab otherwise) - the panel is visible without JS.
- RULE: label: names the tablist (aria-label) - recommended whenever the page has several tab sets.
- RULE: Tabs switch VIEWS of one context; use navigation (links) when the URL should change.


