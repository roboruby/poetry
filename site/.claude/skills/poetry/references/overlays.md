# poetry overlays components

Contracts generated from the registry. `RULE` lines are constraints,
not suggestions. Options are keywords; content is the block.

## alert_dialog (`poetry_alert_dialog`)

A modal dialog that interrupts the user and expects a response.

Class: Poetry::Ui::AlertDialog::Component - BEM block `poetry-ui-alert_dialog`.
Slot REQUIRED: with_title (the accessible name) - a call without it raises.
Slot REQUIRED: with_description (the alertdialog must explain itself) - a call without it raises.
Slot REQUIRED: with_action (the confirming choice) - a call without it raises.
Slot REQUIRED: with_cancel (the safe way out) - a call without it raises.
- `size:` (symbol) - one of default|sm, default "default", required - The panel size; :sm compacts the layout and switches the footer to a two-column grid.
- `content_class:` (string) - Extra classes merged onto the panel element.
Slots: trigger (The button that opens the dialog; keywords are forwarded as Button props.; takes poetry_button props, not a block; with_trigger yields NOTHING to the block - no |param|, write content directly), title (The heading - the dialog's accessible name (required).), description (The explanation read alongside the title by assistive tech (required).), media (Optional icon/illustration well above the title.), action (The confirming choice (required) - a Button; pass variant: :destructive for deletes. Activating it also closes the dialog (a caller-supplied data-action opts out).; takes poetry_button props, not a block; with_action yields NOTHING to the block - no |param|, write content directly), cancel (The safe way out (required) - an outline Button that takes initial focus and closes the dialog on activation.; takes poetry_button props, not a block; with_cancel yields NOTHING to the block - no |param|, write content directly).
- PART `alert-dialog` - Root wrapper around the trigger and the <dialog> element
- PART `alert-dialog-content` - The role=alertdialog <dialog> panel - sizing, animation, and the open state ride here | states: data-open (panel is open (the shared dialog controller flips the pair at runtime)); data-closed (panel is closed (the server-rendered state)); data-size=default|sm (always - the resolved size)
- PART `alert-dialog-header` - Title block - holds the optional media well, the title, and the description
- PART `alert-dialog-media` - The optional media well above the title (an icon or illustration) - the header's first row; absent unless with_media is used
- PART `alert-dialog-title` - The heading - the alertdialog's accessible name (required slot)
- PART `alert-dialog-description` - The explanation, wired to aria-describedby (required slot)
- PART `alert-dialog-footer` - The choice row - cancel then action
- WIRING root: `poetry--core--dialog` registers; values dismissible
- WIRING content: `poetry--core--dialog` actions close on cancel, backdropClose on click; targets dialog
- WIRING trigger: `poetry--core--dialog` actions open
- WIRING close: `poetry--core--dialog` actions close
- RULE: with_trigger(compose: true) { |wiring| ... } composes YOUR control as the trigger: the block is yielded the trigger wiring (the Stimulus behavior the overlay needs; poppers add id/aria and their trigger slot, modals hand only the open action) - splat it onto a wiring-free control (poetry_sidebar_menu_button, a plain tag); without compose: the classic composed Button renders.
- RULE: Destructive confirmations use AlertDialog with with_action(variant: :destructive) - never a bare Dialog, never data-turbo-confirm.
- RULE: with_title AND with_description are REQUIRED (both raise).
- RULE: The action must be an explicit user activation - agents NEVER auto-submit the action.
- RULE: No extra form fields inside an AlertDialog - if input is needed, use a Dialog.
- RULE: Cancel keeps variant: :outline; do not make cancel visually primary.

## command (`poetry_command`)

A command palette for fast, keyboard-driven search and actions.

Class: Poetry::Ui::Command::Component - BEM block `poetry-ui-command`.
REQUIRED - one of id: / aria-label: / aria-labelledby: / aria: (the input's accessible name); a call satisfying none raises.
- `disabled:` (boolean) - default false - Disables the filter input.
- `filter:` (boolean) - default true - Client-side filtering; false leaves the list server-driven.
- `id:` (string) - The base DOM id; the input, list, and item ids derive from it.
- `list_label:` (string) - default "dynamic" - The listbox's accessible name.
- `loop:` (boolean) - default false - Wraps arrow-key highlight movement past either end of the list.
- `placeholder:` (string) - The filter input's placeholder text.
- `value:` (string) - Seats the initial highlight on the item with this value.
Slots: empty (Custom zero-results content (defaults to t('poetry.command.empty')).), loading (Custom pending content (a spinner); the HOST toggles visibility (Turbo frame events) - Command renders the part, never sets it.), items (The item UNION: item | group (heading + items) | separator - one ordered collection (interleaving preserved; items and groups are part COMPONENTS so id assignment follows render/DOM order).; many; types item|group|separator - one with_<type> setter each, options as keywords).
- PART `command` - Root of the palette - the input row over the listbox, carrying the engine controller
- PART `command-input-wrapper` - The input row - search icon + filter input above the list
- PART `command-search-icon` - Decorative search glyph beside the input
- PART `command-input` - The role=combobox filter input - real focus stays pinned here for the whole session; the highlight rides aria-activedescendant
- PART `command-list` - The role=listbox holding empty/loading/items - the input's aria-controls target
- PART `command-empty` - Zero-matches message - rendered hidden; the controller unhides it when the filter pass leaves no visible items
- PART `command-loading` - Pending affordance (role=status) - rendered hidden; the HOST toggles it (Turbo frame events), Command never does
- PART `command-group` - role=group labelled by its heading - hidden by the controller when every member item is filtered out | states: data-always-render (always_render: is set - the group survives every filter pass)
- PART `command-group-heading` - The group heading - styled, no ARIA role (the group points at it via aria-labelledby)
- PART `command-item` - One role=option action row - highlight, filtering, and disablement ride here (never aria-selected in a bare Command) | states: data-value (always - the item's unique value (its server-stable id follows registration order)); data-highlighted (the item holds the highlight (bare; the controller twin-writes it with the input's aria-activedescendant)); data-disabled (disabled: is set (aria-disabled rides along)); data-keywords (keywords: given - extra filter terms beyond the label); data-always-render (always_render: is set - the item survives every filter pass); data-hidden (the filter scored the item zero (the controller pairs it with hidden; never rendered server-side))
- PART `command-item-text` - The item's label span - the filter/typematch text source (shortcuts and icons excluded)
- PART `command-shortcut` - Presentational keyboard hint - excluded from the filter text; Command never binds the hinted key
- PART `command-separator` - Decorative divider (aria-hidden) - hidden by the controller whenever the query is non-empty
- PART `command-status` - The sr-only polite result-count live region - the controller writes the debounced count from the localized templates | states: data-zero (always - the localized zero-results template); data-one (always - the localized one-result template); data-other (always - the localized many-results template (a literal count placeholder the controller interpolates))
- WIRING root: `poetry--core--command` registers; values filter, loop
- WIRING input: `poetry--core--command` actions filterInput on input, keydown on keydown
- WIRING item: `poetry--core--command` actions activate on click, pointerHighlight on pointermove
- RULE: Use poetry_command - never hand-roll a filterable listbox with an input + a list and ad-hoc JS.
- RULE: Command items DO things; they carry no form value. Picking a value for a form is Combobox (which wraps this) - never bind a hidden input to a bare Command.
- RULE: Every item needs a unique value: (ArgumentError) and gets a server id - never strip item ids (aria-activedescendant depends on them).
- RULE: Never put tabindex or focus on options; never write aria-selected in a bare Command - highlight is data-highlighted + activedescendant only.
- RULE: Filtering is hide-only: never reorder, remove, or re-append items to 'sort' results - DOM order is the contract.
- RULE: The poetry:command:select event is the ONLY activation surface - act in a listener (or item data-action); don't patch the controller to navigate.
- RULE: Long/async data: filter: false + a Turbo frame (the recipe) - don't render 5,000 items and hope.
- RULE: Icon-rich labels: set filter_value:/keywords: rather than stuffing hidden text into items.

## command_dialog (`poetry_command_dialog`)

The command palette in a modal dialog, summonable from anywhere.

Class: Poetry::Ui::Command::DialogComponent - BEM block `poetry-ui-command-dialog`.
- `description:` (string) - default "dynamic" - The sr-only description wired to aria-describedby (localized default).
- `dismissible:` (boolean) - default true - Backdrop clicks close the palette; false keeps it open.
- `filter:` (boolean) - default true - Passed through to the embedded Command: client-side filtering.
- `hotkey:` (string) - A global shortcut ("meta+k") that toggles the palette from anywhere; an accelerator, not the only way in.
- `id:` (string) - Passed through: the embedded palette's base DOM id.
- `list_label:` (string) - Passed through: the listbox's accessible name.
- `loop:` (boolean) - default false - Passed through: wraps arrow-key highlight movement at the ends.
- `placeholder:` (string) - Passed through: the filter input's placeholder text.
- `show_close_button:` (boolean) - default "dynamic" - The close X, seated in the input row. Off by default while backdrop clicks close the palette (Esc, the backdrop, or picking an item all close it); on when dismissible: false so a pointer has a way out. Pass true to always show it.
- `title:` (string) - default "dynamic" - The dialog's sr-only accessible name (localized default) - override rather than remove.
- `value:` (string) - Passed through: seats the initial highlight on this item value.
Slots: trigger (The trigger is a poetry Button wired to open - the Dialog pattern: with_trigger(variant: :outline) { "Open palette" }.; with_trigger yields NOTHING to the block - no |param|, write content directly).
- PART `command-dialog` - Root wrapper around the trigger and the <dialog> - the palette's own chrome; the embedded Command inside carries its own part contract
- PART `dialog-content` - The <dialog> panel (Dialog's chrome retuned to overflow-hidden p-0) - positioning, animation, and the open state ride here | states: data-open (panel is open (the dialog controller flips the pair at runtime)); data-closed (panel is closed or animating out (the server-rendered state))
- PART `dialog-header` - Dialog's title block, sr-only here - the palette owns the visible surface
- PART `dialog-title` - The sr-only heading - the dialog's accessible name (defaults to the source string)
- PART `dialog-description` - The sr-only description wired to aria-describedby
- WIRING root: `poetry--core--dialog` registers; values dismissible, hotkey (if)
- WIRING content: `poetry--core--dialog` actions close on cancel, backdropClose on click; targets dialog
- WIRING trigger: `poetry--core--dialog` actions open
- WIRING close: `poetry--core--dialog` actions close
- RULE: App-wide palettes use poetry_command_dialog with hotkey: ('meta+k') - never a hand-wired window keydown listener around poetry_dialog.
- RULE: Open it with with_trigger(...) too - the hotkey is an accelerator, not the only way in.
- RULE: The sr-only title/description default to the source strings - override title:/description: rather than removing them (they are the dialog's accessible name).
- RULE: Item wiring is Command's: act on poetry:command:select; close the dialog in the listener if the action should dismiss the palette.
- RULE: The close X is off by default (keyboard-first: Esc, the backdrop, or picking an item closes it) and appears with dismissible: false; show_close_button: true forces it - it seats in the input row, never over it.

## context_menu (`poetry_context_menu`)

A menu of actions revealed by right-clicking an element.

Class: Poetry::Ui::ContextMenu::Component - BEM block `poetry-ui-context_menu`.
Slot REQUIRED: with_trigger (the right-click surface) - a call without it raises.
Slot REQUIRED: with_item (at least one item) - a call without it raises.
- `dir:` (symbol) - one of ltr|rtl - Writing-direction override (ltr/rtl) stamped on the root.
- `disabled:` (boolean) - default false - Inerts the surface - no gesture opens the menu.
- `focusable_surface:` (boolean) - default false - Puts the surface in the tab order and advertises Shift+F10.
- `label:` (string) - The menu's accessible name (localized fallback when omitted).
- `long_press_delay:` (integer) - default 700 - Touch long-press duration in ms before the menu opens.
- `loop:` (boolean) - default false - Wraps arrow-key movement past either end of the menu.
- `modal:` (boolean) - default true - Traps focus in the open menu; false keeps the page interactive.
- `open:` (boolean) - default false - Server-renders the menu open (rare - context menus normally open from the gesture).
- `side:` (symbol) - one of top|right|bottom|left, default "right" - Which side of the pointer the menu opens toward; collisions may still flip it.
Slots: items (The menu composition API: one ordered items collection accepting seven kinds, interleaved in call order - with_item an action row (href: renders it as a real link; submit: as a real submit button) with_checkbox_item a toggleable checked/unchecked row with_radio_group a single-select scope; add rows inside it via with_radio_item(value:) with_label a non-interactive heading for a run of items with_separator a horizontal rule between runs with_group semantic grouping around the same union, one level down with_sub a nested submenu: its own with_trigger plus the same union, recursively; many; types item|checkbox_item|radio_group|label|separator|group|sub - one with_<type> setter each, options as keywords; with_item/with_checkbox_item/with_label yield NOTHING to the block - no |param|, write content directly; each with_radio_group REQUIRES with_radio_item inside its block (at least one radio item); each with_group REQUIRES with_item inside its block (at least one item); each with_sub REQUIRES with_trigger inside its block (the sub-menu item); each with_sub REQUIRES with_item inside its block (at least one item)), trigger (The right-click/long-press SURFACE: wraps arbitrary content (a card, a row, a region); polymorphic tag: (default :span, set tag: :div to wrap block content). NOT a button: no role, no aria-haspopup, no tabindex by default. The inline -webkit-touch-callout suppresses the iOS callout so long-press can run (iOS never fires contextmenu; the timer is the only touch path there).; with_trigger yields NOTHING to the block - no |param|, write content directly).
- PART `context-menu` - Root wrapper hosting the context-menu + menu + popper controllers around the surface and content
- PART `context-menu-trigger` - The right-click/long-press SURFACE wrapping the logical object - not a widget: no role, no aria-haspopup | states: data-popup-open (the menu is open (absence is the closed state - no aria-expanded on a role-less surface)); data-disabled (the surface is inert (disabled: true))
- PART `context-menu-content` - The role=menu popup panel - anchored at the pointer via popper's virtual-anchor mode; open state and animation ride here | states: data-open (menu is open (presence flips the pair at runtime)); data-closed (menu is closed or animating out (the server-rendered state)); data-side=top|right|bottom|left (the placement side (the side: option, default right; popper re-writes it after collision flips)); data-align=start|center|end (the alignment (forced start initially; popper re-resolves it)) | vars: --transform-origin (popper's anchor-facing animation origin); --available-width (popper: viewport space left for the panel (post-flip)); --available-height (popper: viewport space left for the panel (post-flip)); --anchor-width (popper: the anchor rect's measured width); --anchor-height (popper: the anchor rect's measured height)
- PART `context-menu-group` - role=group semantic grouping between separators
- PART `context-menu-label` - Non-interactive heading for a run of items | states: data-inset (indented to align with checkbox/radio item text (inset: true))
- PART `context-menu-item` - One role=menuitem action row | states: data-variant (default or destructive (the danger treatment)); data-inset (indented to align with checkbox/radio item text (inset: true)); data-disabled (item is disabled (always written together with aria-disabled))
- PART `context-menu-checkbox-item` - A role=menuitemcheckbox toggle row | states: data-checked (checked (the controller re-writes the pair with aria-checked on activation)); data-unchecked (unchecked); data-disabled (item is disabled (always written together with aria-disabled)); data-close-on-select (per-item override of the menu's close-on-select default ("false" keeps the menu open))
- PART `context-menu-radio-group` - role=group scoping one single-select value | states: data-value (the selected radio value (the controller re-writes it on change))
- PART `context-menu-radio-item` - A role=menuitemradio row inside a radio group | states: data-checked (the selected radio (the controller re-writes the pair with aria-checked)); data-unchecked (not selected); data-value (the radio's value); data-disabled (item is disabled (always written together with aria-disabled))
- PART `context-menu-checkbox-item-indicator` - The check glyph inside checkbox items (aria-hidden; the item carries the checked state)
- PART `context-menu-radio-item-indicator` - The circle glyph inside radio items (aria-hidden; the item carries the checked state)
- PART `context-menu-separator` - role=separator rule between groups
- PART `context-menu-shortcut` - The trailing keybinding HINT - aria-hidden, never binds the key
- PART `context-menu-sub` - A submenu scope - hosts its own popper around the sub trigger/content pair
- PART `context-menu-sub-trigger` - The role=menuitem row opening its submenu | states: data-popup-open (its submenu is open (written with aria-expanded; absence is the closed state)); data-inset (indented to align with checkbox/radio item text (inset: true))
- PART `context-menu-sub-content` - The nested role=menu panel - its own popper content on the same presence machinery | states: data-open (submenu is open (presence flips the pair at runtime)); data-closed (submenu is closed (the server-rendered state)); data-side=top|right|bottom|left (the placement side (right/left by direction; popper resolves it at runtime)); data-align=start|center|end (the alignment against the sub-trigger (popper resolves it at runtime)) | vars: --transform-origin (popper's anchor-facing animation origin); --available-width (popper: viewport space left for the panel (post-flip)); --available-height (popper: viewport space left for the panel (post-flip)); --anchor-width (popper: the sub-trigger's measured width); --anchor-height (popper: the sub-trigger's measured height)
- WIRING root: `poetry--core--context-menu` registers; values long_press_delay, disabled | `poetry--core--menu` registers; values open, modal, loop | `poetry--core--popper` registers; values side, align, side_offset, avoid_collisions
- WIRING trigger: `poetry--core--context-menu` actions open on contextmenu, pressStart on pointerdown, pressCancel on pointermove/pointerup/pointercancel | `poetry--core--popper` targets anchor
- WIRING content: `poetry--core--popper` targets content
- WIRING item: `poetry--core--menu` actions activate on click
- WIRING sub_trigger: `poetry--core--menu` actions subEnter on pointerenter, subLeave on pointerleave, openSub on click | `poetry--core--popper` targets anchor
- RULE: NEVER make a context menu the only path to an action - it is an invisible affordance; every item needs a visible equivalent (a '...' DropdownMenu button, a toolbar, a detail page).
- RULE: Choose ContextMenu only for right-click-on-an-object semantics; a visible button opening a menu is DropdownMenu.
- RULE: Do not add aria-haspopup or a role to the trigger surface; do not make it focusable except via focusable_surface: true.
- RULE: side: picks which side of the pointer the menu opens toward (top/right/bottom/left, default :right); align and offsets are not API - collisions still flip the side.
- RULE: Wrap the whole logical object (row/card) as the trigger surface, not a fragment.
- RULE: Destructive items use variant: :destructive AND still confirm irreversible actions via a dialog.
- RULE: shortcut: is a visual hint only - it does NOT bind the key.
- RULE: Do not nest a ContextMenu trigger surface inside another ContextMenu trigger surface.

## dialog (`poetry_dialog`)

A window overlaid on the page for content that requires attention.

Class: Poetry::Ui::Dialog::Component - BEM block `poetry-ui-dialog`.
Slot REQUIRED: with_title (the accessible name) - a call without it raises.
- `content_class:` (string) - Extra classes merged onto the <dialog> panel (e.g. "max-h-[50vh]" caps a top/bottom sheet).
- `dismissible:` (boolean) - default true - Backdrop clicks close the dialog; false keeps confirmations from being dismissed accidentally (Esc still closes).
- `show_close_button:` (boolean) - default true - Renders the corner X; false forces a deliberate footer choice (footer actions and Esc remain). Sheet inherits this.
Slots: trigger (The trigger is a poetry Button wired to open the dialog - agents pass Button props: with_trigger(variant: :outline) { "Open" }.; takes poetry_button props, not a block; with_trigger yields NOTHING to the block - no |param|, write content directly), title (The heading - the dialog's accessible name; required.), description (Muted copy under the title, wired to aria-describedby.), footer (The action row at the bottom of the panel.).
- PART `dialog` - Root wrapper around the trigger and the <dialog> element
- PART `dialog-content` - The <dialog> panel - positioning, animation, and the open state ride here | states: data-open (panel is open (the controller flips the pair at runtime)); data-closed (panel is closed or animating out (the server-rendered state))
- PART `dialog-header` - Title block at the top of the panel
- PART `dialog-title` - The heading - the dialog's accessible name (required slot)
- PART `dialog-description` - Muted copy under the title, wired to aria-describedby
- PART `dialog-footer` - Action row at the bottom of the panel
- WIRING root: `poetry--core--dialog` registers; values dismissible
- WIRING content: `poetry--core--dialog` actions close on cancel, backdropClose on click; targets dialog
- WIRING trigger: `poetry--core--dialog` actions open
- WIRING close: `poetry--core--dialog` actions close
- tool open (mutating) - Open the dialog. [opt in with webmcp: "name" on the call; dispatches poetry--core--dialog#open]
- tool close (mutating) - Close the dialog. [opt in with webmcp: "name" on the call; dispatches poetry--core--dialog#close]
- RULE: with_trigger(compose: true) { |wiring| ... } composes YOUR control as the trigger: the block is yielded the trigger wiring (the Stimulus behavior the overlay needs; poppers add id/aria and their trigger slot, modals hand only the open action) - splat it onto a wiring-free control (poetry_sidebar_menu_button, a plain tag); without compose: the classic composed Button renders.
- RULE: Open dialogs with with_trigger(...) - never a hand-wired button.
- RULE: with_title is REQUIRED (the accessible name); with_description when the purpose needs explaining.
- RULE: Confirmations that must not be lost use dismissible: false (backdrop clicks stop closing).
- RULE: show_close_button: false removes the corner X - keep a footer action (Esc still closes).
- RULE: Destructive confirmations pair a destructive Button in the footer - never auto-submit.

## drawer (`poetry_drawer`)

A gesture-driven panel that slides in from a screen edge.

Class: Poetry::Ui::Drawer::Component - BEM block `poetry-ui-drawer`.
Slot REQUIRED: with_title (the accessible name) - a call without it raises.
- `direction:` (symbol) - one of down|up|left|right, default "down", required - The dismiss direction - :down is the mobile bottom sheet; the edge chrome and swipe axis derive from it.
- `content_class:` (string) - Extra classes merged onto the <dialog> panel (e.g. "max-h-[50vh]" caps a top/bottom sheet).
- `dismissible:` (boolean) - default true - Backdrop clicks close the dialog; false keeps confirmations from being dismissed accidentally (Esc still closes).
- `modal:` (boolean) - default true - Non-modal (false) opens with show() - no top layer, no scrim, no focus trap, no scroll lock; the page behind stays interactive. Esc (while focus is inside), the swipe, and any wired close button still exit; there is no backdrop to click, so pointer dismissal is off by nature.
- `show_swipe_handle:` (boolean) - default false - Renders the grab pill so the swipe gesture is discoverable.
- `snap_points:` () - Preset resting heights for a bottom sheet, ascending: fractions of the full height (0..1] or CSS px/rem lengths (["31rem", 1]). The popup runs full-height and opens at the first point; drags move between points, below the first dismisses. direction: :down only.
Slots: trigger (The trigger is a poetry Button wired to open the dialog - agents pass Button props: with_trigger(variant: :outline) { "Open" }.; takes poetry_button props, not a block; with_trigger yields NOTHING to the block - no |param|, write content directly), title (The heading - the dialog's accessible name; required.), description (Muted copy under the title, wired to aria-describedby.), footer (The action row at the bottom of the panel.).
- PART `drawer` - Root wrapper around the trigger and the <dialog> element
- PART `drawer-content` - The <dialog> popup - the edge chrome, presence animation, and the swipe contract all ride here (::backdrop inherits the swipe vars, so the overlay fade rides along) | states: data-open (popup is open (the controller flips the pair at runtime)); data-closed (popup is closed or animating out (the server-rendered state)); data-swipe-direction=down|up|left|right (always - the dismiss direction); data-swiping (a pointer drag is tracking (transitions go duration-0 - the drawer follows the finger)); data-snap-points (snap_points: present - the popup runs full-height and --drawer-snap-point-offset rests it at the current point); data-starting-style (the enter transition's first frame (the presence helper's two-frame trick)); data-ending-style (held through the exit transition before the native close()) | vars: --drawer-swipe-movement-x (px dragged toward a left/right dismissal (controller-written during swipes)); --drawer-swipe-movement-y (px dragged toward an up/down dismissal (controller-written during swipes)); --drawer-swipe-progress (0..1 fraction of the dismiss travel (the backdrop fade rides it)); --drawer-swipe-strength (remaining-travel factor set on release - scales the exit duration so a mostly-swiped drawer closes fast)
- PART `drawer-swipe-handle` - The grab pill (show_swipe_handle: true, aria-hidden) - a drag may always start on it
- PART `drawer-header` - Title block at the top of the popup
- PART `drawer-title` - The heading - the drawer's accessible name (required slot)
- PART `drawer-description` - Muted copy under the title, wired to aria-describedby
- PART `drawer-body` - The scrollable content region between header and footer
- PART `drawer-footer` - Action row pinned to the bottom of the popup
- WIRING root: `poetry--core--drawer` registers; values dismissible, direction, modal, snap_points (if)
- WIRING content: `poetry--core--drawer` actions close on cancel, backdropClose on click, escapeClose on keydown (unless modal), swipeStart on pointerdown, swipeMove on pointermove, swipeEnd on pointerup, swipeCancel on pointercancel; targets dialog
- WIRING trigger: `poetry--core--drawer` actions open
- WIRING close: 
- tool open (mutating) - Open the drawer. [opt in with webmcp: "name" on the call; dispatches poetry--core--drawer#open]
- tool close (mutating) - Close the drawer. [opt in with webmcp: "name" on the call; dispatches poetry--core--drawer#close]
- RULE: Open drawers with with_trigger(...) - never a hand-wired button.
- RULE: with_title is REQUIRED (the accessible name) - the inherited Dialog rule.
- RULE: direction: is the DISMISS direction: :down is the mobile bottom sheet (the default); left/right make an edge panel - prefer Sheet on desktop.
- RULE: show_swipe_handle: true renders the grab pill - use it on bottom sheets so the gesture is discoverable.
- RULE: Esc and the backdrop still dismiss (the platform trap) - the swipe is an addition, never the only way out.
- RULE: modal: false keeps the page interactive (no scrim, no focus trap) - pair a wired footer close; Esc while focus is inside still exits.
- RULE: snap_points: ["31rem", 1] snaps a bottom sheet between preset heights (ascending fractions or px/rem lengths; opens at the first) - direction: :down only.

## dropdown_menu (`poetry_dropdown_menu`)

A menu of actions or options triggered by a button.

Class: Poetry::Ui::DropdownMenu::Component - BEM block `poetry-ui-dropdown_menu`.
Slot REQUIRED: with_trigger (the menu button) - a call without it raises.
Slot REQUIRED: with_item (at least one item) - a call without it raises.
- `align:` (symbol) - one of start|center|end, default "center" - The menu's alignment against the trigger's edge.
- `align_offset:` (integer) - default 0 - Pixel shift along the alignment edge.
- `avoid_collisions:` (boolean) - default true - Flips/shifts placement to keep the menu inside the viewport.
- `dir:` (symbol) - one of ltr|rtl - Reading direction; :rtl flips submenu sides and indicators.
- `disabled:` (boolean) - default false - Disables the menu trigger button.
- `loop:` (boolean) - default false - Arrow-key navigation wraps from the last item back to the first.
- `modal:` (boolean) - default true - While open, pointer interaction outside the menu is blocked; false keeps the rest of the page interactive.
- `open:` (boolean) - default false - Renders the menu already open on page load.
- `side:` (symbol) - one of top|right|bottom|left, default "bottom" - Which side of the trigger the menu opens on (flips on collision).
- `side_offset:` (integer) - default 4 - Gap in pixels between the trigger and the menu.
Slots: items (The menu composition API: one ordered items collection accepting seven kinds, interleaved in call order - with_item an action row (href: renders it as a real link; submit: as a real submit button) with_checkbox_item a toggleable checked/unchecked row with_radio_group a single-select scope; add rows inside it via with_radio_item(value:) with_label a non-interactive heading for a run of items with_separator a horizontal rule between runs with_group semantic grouping around the same union, one level down with_sub a nested submenu: its own with_trigger plus the same union, recursively; many; types item|checkbox_item|radio_group|label|separator|group|sub - one with_<type> setter each, options as keywords; with_item/with_checkbox_item/with_label yield NOTHING to the block - no |param|, write content directly; each with_radio_group REQUIRES with_radio_item inside its block (at least one radio item); each with_group REQUIRES with_item inside its block (at least one item); each with_sub REQUIRES with_trigger inside its block (the sub-menu item); each with_sub REQUIRES with_item inside its block (at least one item)), trigger (The menu button - a poetry Button (options forward to it, e.g. variant: :outline). The slot owns the aria-haspopup/expanded/ controls wiring regardless of the composed content, so composition cannot drop the aria.; takes poetry_button props, not a block; with_trigger yields NOTHING to the block - no |param|, write content directly).
- PART `dropdown-menu` - Root wrapper hosting the menu + popper controllers around the trigger and content
- PART `dropdown-menu-content` - The role=menu popup panel - positioning, animation, and the open state ride here | states: data-open (menu is open (presence flips the pair at runtime)); data-closed (menu is closed or animating out (the server-rendered state)); data-side=top|right|bottom|left (the placement side (popper re-writes it after collision flips)); data-align=start|center|end (the alignment against the trigger (popper re-resolves it)) | vars: --transform-origin (popper's anchor-facing animation origin); --available-width (popper: viewport space left for the panel (post-flip)); --available-height (popper: viewport space left for the panel (post-flip)); --anchor-width (popper: the trigger's measured width); --anchor-height (popper: the trigger's measured height)
- PART `dropdown-menu-group` - role=group semantic grouping between separators
- PART `dropdown-menu-label` - Non-interactive heading for a run of items | states: data-inset (indented to align with checkbox/radio item text (inset: true))
- PART `dropdown-menu-item` - One role=menuitem action row | states: data-variant (default or destructive (the danger treatment)); data-inset (indented to align with checkbox/radio item text (inset: true)); data-disabled (item is disabled (always written together with aria-disabled))
- PART `dropdown-menu-checkbox-item` - A role=menuitemcheckbox toggle row | states: data-checked (checked (the controller re-writes the pair with aria-checked on activation)); data-unchecked (unchecked); data-disabled (item is disabled (always written together with aria-disabled)); data-close-on-select (per-item override of the menu's close-on-select default ("false" keeps the menu open))
- PART `dropdown-menu-radio-group` - role=group scoping one single-select value | states: data-value (the selected radio value (the controller re-writes it on change))
- PART `dropdown-menu-radio-item` - A role=menuitemradio row inside a radio group | states: data-checked (the selected radio (the controller re-writes the pair with aria-checked)); data-unchecked (not selected); data-value (the radio's value); data-disabled (item is disabled (always written together with aria-disabled))
- PART `dropdown-menu-checkbox-item-indicator` - The check glyph inside checkbox items (aria-hidden; the item carries the checked state)
- PART `dropdown-menu-radio-item-indicator` - The circle glyph inside radio items (aria-hidden; the item carries the checked state)
- PART `dropdown-menu-separator` - role=separator rule between groups
- PART `dropdown-menu-shortcut` - The trailing keybinding HINT - aria-hidden, never binds the key
- PART `dropdown-menu-sub` - A submenu scope - hosts its own popper around the sub trigger/content pair
- PART `dropdown-menu-sub-trigger` - The role=menuitem row opening its submenu | states: data-popup-open (its submenu is open (written with aria-expanded; absence is the closed state)); data-inset (indented to align with checkbox/radio item text (inset: true))
- PART `dropdown-menu-sub-content` - The nested role=menu panel - its own popper content on the same presence machinery | states: data-open (submenu is open (presence flips the pair at runtime)); data-closed (submenu is closed (the server-rendered state)); data-side=top|right|bottom|left (the placement side (right/left by direction; popper resolves it at runtime)); data-align=start|center|end (the alignment against the sub-trigger (popper resolves it at runtime)) | vars: --transform-origin (popper's anchor-facing animation origin); --available-width (popper: viewport space left for the panel (post-flip)); --available-height (popper: viewport space left for the panel (post-flip)); --anchor-width (popper: the sub-trigger's measured width); --anchor-height (popper: the sub-trigger's measured height)
- WIRING root: `poetry--core--menu` registers; values open, modal, loop | `poetry--core--popper` registers; values side, align, side_offset, align_offset, avoid_collisions
- WIRING trigger: `poetry--core--menu` actions toggle on click, triggerKeydown on keydown | `poetry--core--popper` targets anchor
- WIRING content: `poetry--core--popper` targets content
- WIRING item: `poetry--core--menu` actions activate on click
- WIRING sub_trigger: `poetry--core--menu` actions subEnter on pointerenter, subLeave on pointerleave, openSub on click | `poetry--core--popper` targets anchor
- RULE: with_trigger(compose: true) { |wiring| ... } composes YOUR control as the trigger: the block is yielded the trigger wiring (the Stimulus behavior the overlay needs; poppers add id/aria and their trigger slot, modals hand only the open action) - splat it onto a wiring-free control (poetry_sidebar_menu_button, a plain tag); without compose: the classic composed Button renders.
- RULE: Use poetry_dropdown_menu - never hand-roll role=menu popups with Tailwind.
- RULE: Items are ACTIONS. Choosing a form VALUE is a Select/Combobox - do not fake it with radio items.
- RULE: Navigation items pass with_item(href:) (external: for a new tab); a form action (sign-out, a DELETE) passes with_item(submit:, method:). The item renders AS the anchor / submit button (role=menuitem on the <a> or <button>) - one interactive element - so NEVER nest a link_to or button_to inside an item.
- RULE: Icon-only triggers MUST have an accessible name (the composed Button's label: rule).
- RULE: Never write the state attributes (data-popup-open / data-checked / data-unchecked) without their aria twin (aria-expanded / aria-checked) - the controller writes both; agents patching DOM must too.
- RULE: Destructive items use variant: :destructive AND still confirm irreversible actions via a dialog.
- RULE: shortcut: is a visual hint only - it does NOT bind the key; wire a real hotkey separately or omit it.
- RULE: Do not nest interactive elements inside items (a menuitem IS the interactive unit).
- RULE: Keep submenus <= 2 levels; prefer grouping + separators over deep nesting.
- RULE: Critical actions must exist somewhere reachable without JS (menus are JS-required interaction).

## hover_card (`poetry_hover_card`)

A card that reveals preview content when its trigger is hovered.

Class: Poetry::Ui::HoverCard::Component - BEM block `poetry-ui-hover_card`.
Slot REQUIRED: with_trigger (the enriched link) - a call without it raises.
- `align:` (symbol) - one of start|center|end, default "center" - Panel alignment along the chosen side.
- `align_offset:` (integer) - default 0 - Shift in pixels along the alignment axis.
- `avoid_collisions:` (boolean) - default true - Flips and shifts the panel to stay inside the viewport.
- `close_delay:` (integer) - default 300 - Close-grace window in ms over the trigger+content pair.
- `content_class:` (string) - The panel's class merge seam - e.g. content_class: "w-80" widens the card.
- `defer:` (string) - Defer the card body to a lazy turbo-frame. The panel is hidden until hover, so the fetch fires on first open for free; the component block (if any) becomes the frame's placeholder.
- `open:` (boolean) - default false - Renders the card already open on page load.
- `open_delay:` (integer) - default 600 - Hover-intent delay in ms before the card opens.
- `side:` (symbol) - one of top|right|bottom|left, default "bottom" - Which side of the anchor the panel opens on.
- `side_offset:` (integer) - default 4 - Gap in pixels between the anchor and the panel.
Slots: trigger (The enriched LINK: a real navigable <a> - THE no-JS fallback. tag: passthrough exists but change it knowingly (an <a> is the contract's fallback story). NO aria-haspopup/expanded/describedby - the card is invisible to the accessibility tree on purpose. Built as a lazy anatomy part (rendered at render time, not at with_trigger time). variant:/size: route through Button::Component - Button's href-implies-anchor keeps the trigger a REAL <a> wearing button styling, so the reachable-elsewhere contract holds.; with_trigger yields NOTHING to the block - no |param|, write content directly).
- PART `hover-card` - Root wrapper around the trigger link and the panel
- PART `hover-card-trigger` - The enriched link itself - simultaneously the no-JS fallback, the touch path, and the keyboard path | states: data-popup-open (bare while the card is open; absent while closed (absence IS the closed state))
- PART `hover-card-content` - The role-less preview panel (invisible to AT on purpose) - positioning, animation, and the open state ride here | states: data-open (card is open (the controller flips the pair at runtime)); data-closed (card is closed (the server-rendered state; hidden rides along)); data-side=top|right|bottom|left (always - the side (initial placement, re-resolved live by popper after flip)); data-align=start|center|end (always - the alignment (re-resolved live by popper)) | vars: --transform-origin (the anchor-facing origin popper writes for scale-in animation); --available-width (viewport space left for the panel (popper, post-flip)); --available-height (viewport space left for the panel (popper, post-flip)); --anchor-width (the anchor's measured width (popper)); --anchor-height (the anchor's measured height (popper))
- WIRING root: `poetry--core--hover-card` registers; values open, open_delay, close_delay | `poetry--core--popper` registers; values side, align, side_offset, align_offset, avoid_collisions
- WIRING trigger: `poetry--core--hover-card` actions pointerEnter on pointerenter, pointerLeave on pointerleave, focusOpen on focus, blurClose on blur, touchGuard on touchstart | `poetry--core--popper` targets anchor
- WIRING content: `poetry--core--popper` targets content
- RULE: with_trigger(compose: true) { |wiring| ... } composes YOUR control as the trigger: the block is yielded the trigger wiring (the Stimulus behavior the overlay needs; poppers add id/aria and their trigger slot, modals hand only the open action) - splat it onto a wiring-free control (poetry_sidebar_menu_button, a plain tag); without compose: the classic composed Button renders.
- RULE: Use poetry_hover_card - never hand-roll hover-div previews.
- RULE: THE REACHABLE-ELSEWHERE RULE (non-negotiable): every piece of information in a hover card MUST exist at the trigger link's destination (or another keyboard/touch-reachable surface). The card is pointer-only enrichment - keyboard and touch users never see inside it.
- RULE: The trigger must be a REAL link with a real href - it is the fallback, the touch path, and the keyboard path all at once. For a button LOOK, pass variant:/size: (renders through Button, still an <a> via href:) - never swap the tag to :button.
- RULE: NO interactive elements inside the card - they get tabindex=-1 stripped and become pointer-only traps. Actions belong in a Popover or at the destination.
- RULE: Don't add aria-expanded/haspopup to the trigger - advertising an unreachable surface is worse than silence.
- RULE: Never use HoverCard for hints (Tooltip) or for content users act on (Popover).
- RULE: Prefer defer: for expensive previews - a lazy turbo-frame that fetches on first open.

## menubar (`poetry_menubar`)

A horizontal bar of menus, like a desktop application menu.

Class: Poetry::Ui::Menubar::Component - BEM block `poetry-ui-menubar`.
Slot REQUIRED: with_menu (at least one menu) - a call without it raises.
- `dir:` (symbol) - one of ltr|rtl - The reading direction; :rtl flips arrow-key movement and submenu sides.
- `label:` (string) - required - The bar's accessible name - a page may hold more than one menubar.
- `loop:` (boolean) - default false - Wraps arrow-key movement past either end of the bar.
- `value:` (string) - Server-renders the menu with this value open (values default to "menu-<position>").
Slots: menus (The top-level menus. Each takes with_trigger (the menu button) plus the family item slots (with_item, with_checkbox_item, with_radio_group, with_sub, with_separator, ...); value: defaults to the menu's position.; many; each with_menu REQUIRES with_trigger inside its block (the top-level menu button); each with_menu REQUIRES with_item inside its block (at least one item)).
- PART `menubar` - The role=menubar bar - one horizontal roving tab stop across the triggers | states: data-open (some menu is open (value present; the coordinator flips the pair)); data-closed (no menu is open)
- PART `menubar-menu` - One logical menu - a display:contents wrapper hosting the trigger + content pair's menu and popper controllers
- PART `menubar-trigger` - The top-level menu button - a role=menuitem INSIDE the bar | states: data-value (the menu's value - the coordinator's open/close key); data-popup-open (its menu is open (written with aria-expanded; absence is the closed state)); data-disabled (trigger is disabled (written together with the disabled property))
- PART `menubar-content` - The role=menu popup panel - positioning, animation, and the open state ride here | states: data-open (menu is open (presence flips the pair at runtime)); data-closed (menu is closed or animating out (the server-rendered state)); data-side=top|right|bottom|left (the placement side (bottom initially; popper re-writes it after collision flips)); data-align=start|center|end (the alignment against the trigger (start initially; popper re-resolves it)) | vars: --transform-origin (popper's anchor-facing animation origin); --available-width (popper: viewport space left for the panel (post-flip)); --available-height (popper: viewport space left for the panel (post-flip)); --anchor-width (popper: the trigger's measured width); --anchor-height (popper: the trigger's measured height)
- PART `menubar-group` - role=group semantic grouping between separators
- PART `menubar-label` - Non-interactive heading for a run of items | states: data-inset (indented to align with checkbox/radio item text (inset: true))
- PART `menubar-item` - One role=menuitem action row | states: data-variant (default or destructive (the danger treatment)); data-inset (indented to align with checkbox/radio item text (inset: true)); data-disabled (item is disabled (always written together with aria-disabled))
- PART `menubar-checkbox-item` - A role=menuitemcheckbox toggle row | states: data-checked (checked (the controller re-writes the pair with aria-checked on activation)); data-unchecked (unchecked); data-disabled (item is disabled (always written together with aria-disabled)); data-close-on-select (per-item override of the menu's close-on-select default ("false" keeps the menu open))
- PART `menubar-radio-group` - role=group scoping one single-select value | states: data-value (the selected radio value (the controller re-writes it on change))
- PART `menubar-radio-item` - A role=menuitemradio row inside a radio group | states: data-checked (the selected radio (the controller re-writes the pair with aria-checked)); data-unchecked (not selected); data-value (the radio's value); data-disabled (item is disabled (always written together with aria-disabled))
- PART `menubar-checkbox-item-indicator` - The check glyph slot inside checkbox items - aria-hidden; the item's aria-checked/data-checked pair carries state
- PART `menubar-radio-item-indicator` - The circle glyph slot inside radio items - aria-hidden; the item's aria-checked/data-checked pair carries state
- PART `menubar-separator` - role=separator rule between groups
- PART `menubar-shortcut` - The trailing keybinding HINT - aria-hidden, never binds the key
- PART `menubar-sub` - A submenu scope - hosts its own popper around the sub trigger/content pair
- PART `menubar-sub-trigger` - The role=menuitem row opening its submenu | states: data-popup-open (its submenu is open (written with aria-expanded; absence is the closed state)); data-inset (indented to align with checkbox/radio item text (inset: true))
- PART `menubar-sub-content` - The nested role=menu panel - its own popper content on the same presence machinery | states: data-open (submenu is open (presence flips the pair at runtime)); data-closed (submenu is closed (the server-rendered state)); data-side=top|right|bottom|left (the placement side (right/left by direction; popper resolves it at runtime)); data-align=start|center|end (the alignment against the sub-trigger (popper resolves it at runtime)) | vars: --transform-origin (popper's anchor-facing animation origin); --available-width (popper: viewport space left for the panel (post-flip)); --available-height (popper: viewport space left for the panel (post-flip)); --anchor-width (popper: the sub-trigger's measured width); --anchor-height (popper: the sub-trigger's measured height)
- WIRING root: `poetry--core--menubar` registers; values value, loop; actions slideAdjacent on poetry:menu:edge-navigate, onMenuClosed on poetry:menu:closed | `poetry--core--roving-focus` registers; values orientation, manage_tabindex, loop; actions keydown on keydown
- WIRING menu_wrapper: `poetry--core--menu` registers; values open, modal | `poetry--core--popper` registers; values side, align, side_offset, align_offset, avoid_collisions
- WIRING trigger: `poetry--core--menubar` actions toggle on pointerdown, hoverSlide on pointerenter, triggerKeydown on keydown | `poetry--core--popper` targets anchor
- WIRING content: `poetry--core--popper` targets content
- WIRING item: `poetry--core--menu` actions activate on click
- WIRING sub_trigger: `poetry--core--menu` actions subEnter on pointerenter, subLeave on pointerleave, openSub on click | `poetry--core--popper` targets anchor
- RULE: Use poetry_menubar for app-chrome command menus ONLY - site navigation is NavigationMenu (untrapped), a single actions menu is DropdownMenu.
- RULE: label: is REQUIRED (the bar's accessible name).
- RULE: Never put non-menuitem interactive elements directly in the bar (breaks roving focus + APG roles) - a Toolbar is the component for mixed controls.
- RULE: shortcut: is a visual hint ONLY - it does not register a keybinding; wire real shortcuts separately.
- RULE: Do not hand-wire hover-open-from-cold; hover only slides between menus once one is open (the gated-hover rule).
- RULE: In-menu item rules (destructive variant, inset, checkbox/radio) follow the DropdownMenu family contract.

## popover (`poetry_popover`)

Rich floating content anchored to a trigger.

Class: Poetry::Ui::Popover::Component - BEM block `poetry-ui-popover`.
Slot REQUIRED: with_trigger (the panel's control) - a call without it raises.
- `align:` (symbol) - one of start|center|end, default "center" - Panel alignment along the chosen side.
- `align_offset:` (integer) - default 0 - Shift in pixels along the alignment axis.
- `avoid_collisions:` (boolean) - default true - Flips and shifts the panel to stay inside the viewport.
- `content_class:` (string) - Class merge seam for the panel itself (e.g. widen the default with content_class: "w-80") - root-level class: styles the wrapper, not the panel.
- `label:` (string) - role=dialog fallback name when no title part is present.
- `modal:` (boolean) - default false - Reserves interaction for the panel while open; the default keeps the rest of the page interactive.
- `open:` (boolean) - default false - Server-renders the panel open.
- `side:` (symbol) - one of top|right|bottom|left, default "bottom" - Which side of the anchor the panel opens on.
- `side_offset:` (integer) - default 4 - Gap in pixels between the anchor and the panel.
Slots: trigger (The control that opens the panel - a composed Button. The slot owns the aria-haspopup/expanded/controls wiring regardless of the composed content, so composition cannot drop the aria; aria-controls renders even while closed (the stable id is the wiring's resolution seam).; takes poetry_button props, not a block; with_trigger yields NOTHING to the block - no |param|, write content directly), anchor (Optional alternate anchor: when present, the panel positions against IT instead of the trigger (targets beat selectors in the positioning fallback chain).; with_anchor yields NOTHING to the block - no |param|, write content directly), title (Panel heading - presence wires the content's aria-labelledby, so the title names the dialog.), description (Supporting text - presence wires the content's aria-describedby.).
- PART `popover` - Root wrapper around the trigger, the optional anchor, and the panel
- PART `popover-anchor` - Optional alternate popper anchor - when present the panel positions against it instead of the trigger
- PART `popover-content` - The role=dialog panel - positioning, animation, and the open state ride here | states: data-open (panel is open (the controller flips the pair at runtime)); data-closed (panel is closed (the server-rendered state; hidden rides along)); data-side=top|right|bottom|left (always - the side (initial placement, re-resolved live by popper after flip)); data-align=start|center|end (always - the alignment (re-resolved live by popper)) | vars: --transform-origin (the anchor-facing origin popper writes for scale-in animation); --available-width (viewport space left for the panel (popper, post-flip)); --available-height (viewport space left for the panel (popper, post-flip)); --anchor-width (the anchor's measured width (popper)); --anchor-height (the anchor's measured height (popper))
- PART `popover-header` - Title block wrapping the title and description (renders only when either is present)
- PART `popover-title` - The heading - the panel's accessible name via aria-labelledby
- PART `popover-description` - Muted copy under the title, wired to aria-describedby
- WIRING root: `poetry--core--popover` registers; values open, modal | `poetry--core--popper` registers; values anchor (unless anchor?), side, align, side_offset, align_offset, avoid_collisions
- WIRING trigger: `poetry--core--popover` actions toggle on click
- WIRING anchor_part: `poetry--core--popper` targets anchor
- WIRING content: `poetry--core--popper` targets content
- RULE: with_trigger(compose: true) { |wiring| ... } composes YOUR control as the trigger: the block is yielded the trigger wiring (the Stimulus behavior the overlay needs; poppers add id/aria and their trigger slot, modals hand only the open action) - splat it onto a wiring-free control (poetry_sidebar_menu_button, a plain tag); without compose: the classic composed Button renders.
- RULE: Use poetry_popover - never hand-roll an anchored role=dialog panel with Tailwind.
- RULE: Popover content is INTERACTIVE - for text-only hover hints use Tooltip; for pointer-only previews use HoverCard.
- RULE: Give the panel a name: use with_title (preferred) or label: - a role=dialog without a name fails the audit.
- RULE: Icon-only triggers MUST have an accessible name (the composed Button's label: rule).
- RULE: Default is NON-modal (modal: false) - reach for modal: true only when stray outside interaction would corrupt the task; reach for Dialog when the task deserves full modality.
- RULE: Critical-path panels must also be reachable without JS (full page or server-rendered open: true) - popovers are JS-required interaction.
- RULE: Do not nest a Popover inside a Popover - restructure (the layer stack allows it; comprehension does not).

## sheet (`poetry_sheet`)

A dialog that slides in from a screen edge.

Class: Poetry::Ui::Sheet::Component - BEM block `poetry-ui-sheet`.
Slot REQUIRED: with_title (the accessible name) - a call without it raises.
- `side:` (symbol) - one of top|right|bottom|left, default "right", required - The edge the sheet slides in from - a physical direction (right stays right in RTL).
- `content_class:` (string) - Extra classes merged onto the <dialog> panel (e.g. "max-h-[50vh]" caps a top/bottom sheet).
- `dismissible:` (boolean) - default true - Backdrop clicks close the dialog; false keeps confirmations from being dismissed accidentally (Esc still closes).
- `show_close_button:` (boolean) - default true - Renders the corner X; false forces a deliberate footer choice (footer actions and Esc remain). Sheet inherits this.
Slots: trigger (The trigger is a poetry Button wired to open the dialog - agents pass Button props: with_trigger(variant: :outline) { "Open" }.; takes poetry_button props, not a block; with_trigger yields NOTHING to the block - no |param|, write content directly), title (The heading - the dialog's accessible name; required.), description (Muted copy under the title, wired to aria-describedby.), footer (The action row at the bottom of the panel.).
- PART `sheet` - Root wrapper around the trigger and the <dialog> element
- PART `sheet-content` - The <dialog> panel, anchored to a screen edge - the slide animation and the open state ride here | states: data-open (panel is open (the controller flips the pair at runtime)); data-closed (panel is closed or animating out (the server-rendered state; the presence-hold close rides the closed slide-out)); data-side=top|right|bottom|left (always - the edge the sheet slides in from)
- PART `sheet-header` - Title block at the top of the panel
- PART `sheet-title` - The heading - the sheet's accessible name (required slot)
- PART `sheet-description` - Muted copy under the title, wired to aria-describedby
- PART `sheet-footer` - Action row pinned to the bottom of the panel
- WIRING root: `poetry--core--sheet` registers; values dismissible
- WIRING content: `poetry--core--sheet` actions close on cancel, backdropClose on click; targets dialog
- WIRING trigger: `poetry--core--sheet` actions open
- WIRING close: `poetry--core--sheet` actions close
- tool open (mutating) - Open the sheet. [opt in with webmcp: "name" on the call; dispatches poetry--core--sheet#open]
- tool close (mutating) - Close the sheet. [opt in with webmcp: "name" on the call; dispatches poetry--core--sheet#close]
- RULE: Open sheets with with_trigger(...) - never a hand-wired button.
- RULE: with_title is REQUIRED (the accessible name) - the inherited Dialog rule.
- RULE: Pick side by content: navigation left, detail/edit right, pickers bottom.
- RULE: Do not put must-not-lose confirmations in a Sheet - that is AlertDialog.
- RULE: Do not rebuild a centered Dialog with a Sheet; use Dialog.

## tooltip (`poetry_tooltip`)

A floating label describing an element on hover or focus.

Class: Poetry::Ui::Tooltip::Component - BEM block `poetry-ui-tooltip`.
Slot REQUIRED: with_trigger (the described control) - a call without it raises.
- `align:` (symbol) - one of start|center|end, default "center" - Panel alignment along the chosen side.
- `align_offset:` (integer) - default 0 - Shift in pixels along the alignment axis.
- `avoid_collisions:` (boolean) - default true - Flips and shifts the panel to stay inside the viewport.
- `content_class:` (string) - The bubble's class merge seam (caller classes win on conflicts).
- `delay_duration:` (integer) - The hover-open delay in ms; nil inherits the provider's (default 0).
- `disable_hoverable_content:` (boolean) - When true the bubble closes as the pointer leaves the trigger - it cannot be hovered into; nil inherits the provider.
- `label:` (string) - Plain-text announcement override for rich content (the visual children stay; the announced body becomes this text).
- `open:` (boolean) - default false - Server-renders the tooltip open.
- `side:` (symbol) - one of top|right|bottom|left, default "top" - Which side of the anchor the panel opens on.
- `side_offset:` (integer) - default 0 - Gap in pixels between the anchor and the panel.
Slots: trigger (The described control - commonly a poetry Button (with_trigger(variant: :outline) { "Hover" }). The slot owns the state + timing wiring regardless of the composed content. NO aria-haspopup/expanded/controls - the tooltip is invisible as a popup; aria-describedby is written by the controller on open (and server-rendered only when open: true).; takes poetry_button props, not a block; with_trigger yields NOTHING to the block - no |param|, write content directly).
- PART `tooltip` - Root wrapper around the trigger and the bubble
- PART `tooltip-content` - The role=tooltip bubble - positioning, animation, and the open state ride here | states: data-open (bubble is open (the controller flips the pair at runtime)); data-closed (bubble is closed (the server-rendered state; hidden rides along)); data-instant=delay|focus (the open skipped the delay - warm-grace/programmatic or keyboard focus (runtime-only; absent on a delayed open)); data-side=top|right|bottom|left (always - the side (initial placement, re-resolved live by popper after flip)); data-align=start|center|end (always - the alignment (re-resolved live by popper)) | vars: --transform-origin (the anchor-facing origin popper writes for scale-in animation); --available-width (viewport space left for the bubble (popper, post-flip)); --available-height (viewport space left for the bubble (popper, post-flip)); --anchor-width (the anchor's measured width (popper)); --anchor-height (the anchor's measured height (popper))
- PART `tooltip-arrow` - The arrow wrapper (aria-hidden) - popper pins it to the bubble's anchor-facing edge and rotates it toward the anchor | states: data-side=top|right|bottom|left (written by popper alongside the content's - the resolved side, for per-side restyling)
- WIRING root: `poetry--core--tooltip` registers; values open, delay_duration (unless), disable_hoverable_content (unless) | `poetry--core--popper` registers; values side, align, side_offset, align_offset, avoid_collisions
- WIRING trigger: `poetry--core--tooltip` actions pointerMove on pointermove, pointerLeave on pointerleave, pointerDown on pointerdown, clickClose on click, focusOpen on focus, blurClose on blur | `poetry--core--popper` targets anchor
- WIRING content: `poetry--core--popper` targets content
- WIRING arrow: `poetry--core--popper` targets arrow
- RULE: with_trigger(compose: true) { |wiring| ... } composes YOUR control as the trigger: the block is yielded the trigger wiring (the Stimulus behavior the overlay needs; poppers add id/aria and their trigger slot, modals hand only the open action) - splat it onto a wiring-free control (poetry_sidebar_menu_button, a plain tag); without compose: the classic composed Button renders.
- RULE: Use poetry_tooltip - never hand-roll title-attribute replacements or hover divs.
- RULE: Tooltip content is TEXT and never interactive/focusable - links, buttons, or inputs inside are a contract violation (use Popover).
- RULE: Never put essential information only in a tooltip - touch users NEVER see it (no long-press path, by design).
- RULE: The tooltip DESCRIBES; it never names. Icon-only triggers still require label: on the composed Button.
- RULE: Wrap toolbar/button rows in ONE poetry_tooltip_provider so the warm grace makes the row feel continuous.
- RULE: Rich visual content needs label: (the plain-text announcement).
- RULE: Do not pin tooltips open as onboarding callouts - that is a Popover.


