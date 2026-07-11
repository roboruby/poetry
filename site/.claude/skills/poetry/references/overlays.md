# poetry overlays components

Contracts generated from the registry. `RULE` lines are constraints,
not suggestions. Options are keywords; content is the block.

## alert_dialog (`poetry_alert_dialog`)

Class: Poetry::Ui::AlertDialog::Component - BEM block `poetry-ui-alert_dialog`.
Slot REQUIRED: with_title (the accessible name) - a call without it raises.
Slot REQUIRED: with_description (the alertdialog must explain itself) - a call without it raises.
Slot REQUIRED: with_action (the confirming choice) - a call without it raises.
Slot REQUIRED: with_cancel (the safe way out) - a call without it raises.
- `size:` (symbol) - one of default|sm, default "default", required
Slots: trigger (takes poetry_button props, not a block; with_trigger yields NOTHING to the block - no |param|, write content directly), title, description, media, action (takes poetry_button props, not a block; with_action yields NOTHING to the block - no |param|, write content directly), cancel (takes poetry_button props, not a block; with_cancel yields NOTHING to the block - no |param|, write content directly).
- WIRING `poetry--core--dialog`: targets dialog; values dismissible, hotkey; actions backdropClose, close, lockScroll, open, toggle, unlockScroll
- RULE: Destructive confirmations use AlertDialog with with_action(variant: :destructive) - never a bare Dialog, never data-turbo-confirm.
- RULE: with_title AND with_description are REQUIRED (both raise).
- RULE: The action must be an explicit user activation - agents NEVER auto-submit the action.
- RULE: No extra form fields inside an AlertDialog - if input is needed, use a Dialog.
- RULE: Cancel keeps variant: :outline; do not make cancel visually primary.

## command (`poetry_command`)

Class: Poetry::Ui::Command::Component - BEM block `poetry-ui-command`.
REQUIRED - one of id: / aria-label: / aria-labelledby: / aria: (the input's accessible name); a call satisfying none raises.
- `disabled:` (boolean) - default false
- `filter:` (boolean) - default true
- `id:` (string)
- `list_label:` (string) - default "dynamic"
- `loop:` (boolean) - default false
- `placeholder:` (string)
- `value:` (string)
Slots: empty, loading, items (many; types item|group|separator - one with_<type> setter each, options as keywords).
- WIRING `poetry--core--command`: values debounce, filter, loop; actions activate, filterInput, highlightItem, keydown, pointerHighlight, reset; events poetry:command:filter, poetry:command:highlight, poetry:command:select
- RULE: Use poetry_command - never hand-roll a filterable listbox with an input + a list and ad-hoc JS.
- RULE: Command items DO things; they carry no form value. Picking a value for a form is Combobox (which wraps this) - never bind a hidden input to a bare Command.
- RULE: Every item needs a unique value: (ArgumentError) and gets a server id - never strip item ids (aria-activedescendant depends on them).
- RULE: Never put tabindex or focus on options; never write aria-selected in a bare Command - highlight is data-highlighted + activedescendant only.
- RULE: Filtering is hide-only: never reorder, remove, or re-append items to 'sort' results - DOM order is the contract.
- RULE: The poetry:command:select event is the ONLY activation surface - act in a listener (or item data-action); don't patch the controller to navigate.
- RULE: Long/async data: filter: false + a Turbo frame (the recipe) - don't render 5,000 items and hope.
- RULE: Icon-rich labels: set filter_value:/keywords: rather than stuffing hidden text into items.

## command_dialog (`poetry_command_dialog`)

Class: Poetry::Ui::Command::DialogComponent - BEM block `poetry-ui-command-dialog`.
- `description:` (string) - default "dynamic"
- `dismissible:` (boolean) - default true
- `filter:` (boolean) - default true
- `hotkey:` (string)
- `id:` (string)
- `list_label:` (string)
- `loop:` (boolean) - default false
- `placeholder:` (string)
- `show_close_button:` (boolean) - default true
- `title:` (string) - default "dynamic"
- `value:` (string)
Slots: trigger (with_trigger yields NOTHING to the block - no |param|, write content directly).
- WIRING `poetry--core--command`: values debounce, filter, loop; actions activate, filterInput, highlightItem, keydown, pointerHighlight, reset; events poetry:command:filter, poetry:command:highlight, poetry:command:select
- WIRING `poetry--core--dialog`: targets dialog; values dismissible, hotkey; actions backdropClose, close, lockScroll, open, toggle, unlockScroll
- RULE: App-wide palettes use poetry_command_dialog with hotkey: ('meta+k') - never a hand-wired window keydown listener around poetry_dialog.
- RULE: Open it with with_trigger(...) too - the hotkey is an accelerator, not the only way in.
- RULE: The sr-only title/description default to the source strings - override title:/description: rather than removing them (they are the dialog's accessible name).
- RULE: Item wiring is Command's: act on poetry:command:select; close the dialog in the listener if the action should dismiss the palette.

## context_menu (`poetry_context_menu`)

Class: Poetry::Ui::ContextMenu::Component - BEM block `poetry-ui-context_menu`.
Slot REQUIRED: with_trigger (the right-click surface) - a call without it raises.
Slot REQUIRED: with_item (at least one item) - a call without it raises.
- `dir:` (symbol) - one of ltr|rtl
- `disabled:` (boolean) - default false
- `focusable_surface:` (boolean) - default false
- `label:` (string)
- `long_press_delay:` (integer) - default 700
- `modal:` (boolean) - default true
- `open:` (boolean) - default false
Slots: items (many; types item|checkbox_item|radio_group|label|separator|group|sub - one with_<type> setter each, options as keywords; with_item/with_checkbox_item/with_label yield NOTHING to the block - no |param|, write content directly; each with_radio_group REQUIRES with_radio_item inside its block (at least one radio item); each with_group REQUIRES with_item inside its block (at least one item); each with_sub REQUIRES with_trigger inside its block (the sub-menu item); each with_sub REQUIRES with_item inside its block (at least one item)), trigger (with_trigger yields NOTHING to the block - no |param|, write content directly).
- WIRING `poetry--core--context-menu`: values disabled, longPressDelay; actions disabledValueChanged, open, pressCancel, pressStart; events poetry:context-menu:open
- WIRING `poetry--core--menu`: values closeOnSelect, loop, modal, open, typeaheadTimeout; actions activate, close, closeSub, keydown, open, openSub, openValueChanged, subEnter, subLeave, toggle, triggerKeydown; events poetry:menu:change, poetry:menu:closed, poetry:menu:edge-navigate, poetry:menu:open, poetry:menu:select
- WIRING `poetry--core--popper`: targets anchor, arrow, content; values align, alignOffset, anchor, anchorPoint, avoidCollisions, side, sideOffset, strategy; actions anchorPointValueChanged, reposition, setAnchor, setAnchorElement
- RULE: NEVER make a context menu the only path to an action - it is an invisible affordance; every item needs a visible equivalent (a '...' DropdownMenu button, a toolbar, a detail page).
- RULE: Choose ContextMenu only for right-click-on-an-object semantics; a visible button opening a menu is DropdownMenu.
- RULE: Do not add aria-haspopup or a role to the trigger surface; do not make it focusable except via focusable_surface: true.
- RULE: Do not try to set side/align/side_offset - context menus anchor at the pointer, always.
- RULE: Wrap the whole logical object (row/card) as the trigger surface, not a fragment.
- RULE: Destructive items use variant: :destructive AND still confirm irreversible actions via a dialog.
- RULE: shortcut: is a visual hint only - it does NOT bind the key.
- RULE: Do not nest a ContextMenu trigger surface inside another ContextMenu trigger surface.

## dialog (`poetry_dialog`)

Class: Poetry::Ui::Dialog::Component - BEM block `poetry-ui-dialog`.
Slot REQUIRED: with_title (the accessible name) - a call without it raises.
- `dismissible:` (boolean) - default true
Slots: trigger (takes poetry_button props, not a block; with_trigger yields NOTHING to the block - no |param|, write content directly), title, description, footer.
- WIRING `poetry--core--dialog`: targets dialog; values dismissible, hotkey; actions backdropClose, close, lockScroll, open, toggle, unlockScroll
- RULE: Open dialogs with with_trigger(...) - never a hand-wired button.
- RULE: with_title is REQUIRED (the accessible name); with_description when the purpose needs explaining.
- RULE: Confirmations that must not be lost use dismissible: false (backdrop clicks stop closing).
- RULE: Destructive confirmations pair a destructive Button in the footer - never auto-submit.

## drawer (`poetry_drawer`)

Class: Poetry::Ui::Drawer::Component - BEM block `poetry-ui-drawer`.
Slot REQUIRED: with_title (the accessible name) - a call without it raises.
- `direction:` (symbol) - one of down|up|left|right, default "down", required
- `dismissible:` (boolean) - default true
- `show_swipe_handle:` (boolean) - default false
Slots: trigger (takes poetry_button props, not a block; with_trigger yields NOTHING to the block - no |param|, write content directly), title, description, footer.
- WIRING `poetry--core--drawer`: targets dialog; values direction, dismissible, hotkey; actions backdropClose, close, lockScroll, open, swipeCancel, swipeEnd, swipeMove, swipeStart, toggle, unlockScroll
- RULE: Open drawers with with_trigger(...) - never a hand-wired button.
- RULE: with_title is REQUIRED (the accessible name) - the inherited Dialog rule.
- RULE: direction: is the DISMISS direction: :down is the mobile bottom sheet (the default); left/right make an edge panel - prefer Sheet on desktop.
- RULE: show_swipe_handle: true renders the grab pill - use it on bottom sheets so the gesture is discoverable.
- RULE: Esc and the backdrop still dismiss (the platform trap) - the swipe is an addition, never the only way out.

## dropdown_menu (`poetry_dropdown_menu`)

Class: Poetry::Ui::DropdownMenu::Component - BEM block `poetry-ui-dropdown_menu`.
Slot REQUIRED: with_trigger (the menu button) - a call without it raises.
Slot REQUIRED: with_item (at least one item) - a call without it raises.
- `align:` (symbol) - one of start|center|end, default "center"
- `align_offset:` (integer) - default 0
- `avoid_collisions:` (boolean) - default true
- `dir:` (symbol) - one of ltr|rtl
- `disabled:` (boolean) - default false
- `loop:` (boolean) - default false
- `modal:` (boolean) - default true
- `open:` (boolean) - default false
- `side:` (symbol) - one of top|right|bottom|left, default "bottom"
- `side_offset:` (integer) - default 4
Slots: items (many; types item|checkbox_item|radio_group|label|separator|group|sub - one with_<type> setter each, options as keywords; with_item/with_checkbox_item/with_label yield NOTHING to the block - no |param|, write content directly; each with_radio_group REQUIRES with_radio_item inside its block (at least one radio item); each with_group REQUIRES with_item inside its block (at least one item); each with_sub REQUIRES with_trigger inside its block (the sub-menu item); each with_sub REQUIRES with_item inside its block (at least one item)), trigger (takes poetry_button props, not a block; with_trigger yields NOTHING to the block - no |param|, write content directly).
- WIRING `poetry--core--menu`: values closeOnSelect, loop, modal, open, typeaheadTimeout; actions activate, close, closeSub, keydown, open, openSub, openValueChanged, subEnter, subLeave, toggle, triggerKeydown; events poetry:menu:change, poetry:menu:closed, poetry:menu:edge-navigate, poetry:menu:open, poetry:menu:select
- WIRING `poetry--core--popper`: targets anchor, arrow, content; values align, alignOffset, anchor, anchorPoint, avoidCollisions, side, sideOffset, strategy; actions anchorPointValueChanged, reposition, setAnchor, setAnchorElement
- RULE: Use poetry_dropdown_menu - never hand-roll role=menu popups with Tailwind.
- RULE: Items are ACTIONS. Choosing a form VALUE is a Select/Combobox - do not fake it with radio items.
- RULE: Icon-only triggers MUST have an accessible name (the composed Button's label: rule).
- RULE: Never write the state attributes (data-popup-open / data-checked / data-unchecked) without their aria twin (aria-expanded / aria-checked) - the controller writes both; agents patching DOM must too.
- RULE: Destructive items use variant: :destructive AND still confirm irreversible actions via a dialog.
- RULE: shortcut: is a visual hint only - it does NOT bind the key; wire a real hotkey separately or omit it.
- RULE: Do not nest interactive elements inside items (a menuitem IS the interactive unit).
- RULE: Keep submenus <= 2 levels; prefer grouping + separators over deep nesting.
- RULE: Critical actions must exist somewhere reachable without JS (menus are JS-required interaction).

## hover_card (`poetry_hover_card`)

Class: Poetry::Ui::HoverCard::Component - BEM block `poetry-ui-hover_card`.
Slot REQUIRED: with_trigger (the enriched link) - a call without it raises.
- `align:` (symbol) - one of start|center|end, default "center"
- `align_offset:` (integer) - default 0
- `avoid_collisions:` (boolean) - default true
- `close_delay:` (integer) - default 300
- `content_class:` (string)
- `defer:` (string)
- `open:` (boolean) - default false
- `open_delay:` (integer) - default 700
- `side:` (symbol) - one of top|right|bottom|left, default "bottom"
- `side_offset:` (integer) - default 4
Slots: trigger.
- WIRING `poetry--core--hover-card`: values closeDelay, open, openDelay; actions blurClose, focusOpen, openValueChanged, pointerEnter, pointerLeave, touchGuard; events poetry:hover-card:closed, poetry:hover-card:open
- WIRING `poetry--core--popper`: targets anchor, arrow, content; values align, alignOffset, anchor, anchorPoint, avoidCollisions, side, sideOffset, strategy; actions anchorPointValueChanged, reposition, setAnchor, setAnchorElement
- RULE: Use poetry_hover_card - never hand-roll hover-div previews.
- RULE: THE REACHABLE-ELSEWHERE RULE (non-negotiable): every piece of information in a hover card MUST exist at the trigger link's destination (or another keyboard/touch-reachable surface). The card is pointer-only enrichment - keyboard and touch users never see inside it.
- RULE: The trigger must be a REAL link with a real href - it is the fallback, the touch path, and the keyboard path all at once.
- RULE: NO interactive elements inside the card - they get tabindex=-1 stripped and become pointer-only traps. Actions belong in a Popover or at the destination.
- RULE: Don't add aria-expanded/haspopup to the trigger - advertising an unreachable surface is worse than silence (Radix-aligned).
- RULE: Never use HoverCard for hints (Tooltip) or for content users act on (Popover).
- RULE: Prefer defer: for expensive previews - a lazy turbo-frame that fetches on first open.

## menubar (`poetry_menubar`)

Class: Poetry::Ui::Menubar::Component - BEM block `poetry-ui-menubar`.
Slot REQUIRED: with_menu (at least one menu) - a call without it raises.
- `dir:` (symbol) - one of ltr|rtl
- `label:` (string) - required
- `loop:` (boolean) - default false
- `value:` (string)
Slots: menus (many; each with_menu REQUIRES with_trigger inside its block (the top-level menu button); each with_menu REQUIRES with_item inside its block (at least one item)).
- WIRING `poetry--core--menu`: values closeOnSelect, loop, modal, open, typeaheadTimeout; actions activate, close, closeSub, keydown, open, openSub, openValueChanged, subEnter, subLeave, toggle, triggerKeydown; events poetry:menu:change, poetry:menu:closed, poetry:menu:edge-navigate, poetry:menu:open, poetry:menu:select
- WIRING `poetry--core--menubar`: values loop, value; actions hoverSlide, onMenuClosed, slideAdjacent, toggle, triggerKeydown, valueValueChanged; events poetry:menubar:value-changed
- WIRING `poetry--core--popper`: targets anchor, arrow, content; values align, alignOffset, anchor, anchorPoint, avoidCollisions, side, sideOffset, strategy; actions anchorPointValueChanged, reposition, setAnchor, setAnchorElement
- WIRING `poetry--core--roving-focus`: values loop, manageTabindex, orientation; actions keydown; events poetry--core--roving-focus:entry
- RULE: Use poetry_menubar for app-chrome command menus ONLY - site navigation is NavigationMenu (untrapped), a single actions menu is DropdownMenu.
- RULE: label: is REQUIRED (the bar's accessible name).
- RULE: Never put non-menuitem interactive elements directly in the bar (breaks roving focus + APG roles) - a Toolbar is the component for mixed controls.
- RULE: shortcut: is a visual hint ONLY - it does not register a keybinding; wire real shortcuts separately.
- RULE: Do not hand-wire hover-open-from-cold; hover only slides between menus once one is open (the gated-hover rule).
- RULE: In-menu item rules (destructive variant, inset, checkbox/radio) follow the DropdownMenu family contract.

## popover (`poetry_popover`)

Class: Poetry::Ui::Popover::Component - BEM block `poetry-ui-popover`.
Slot REQUIRED: with_trigger (the panel's control) - a call without it raises.
- `align:` (symbol) - one of start|center|end, default "center"
- `align_offset:` (integer) - default 0
- `avoid_collisions:` (boolean) - default true
- `content_class:` (string)
- `label:` (string)
- `modal:` (boolean) - default false
- `open:` (boolean) - default false
- `side:` (symbol) - one of top|right|bottom|left, default "bottom"
- `side_offset:` (integer) - default 4
Slots: trigger (takes poetry_button props, not a block; with_trigger yields NOTHING to the block - no |param|, write content directly), anchor (with_anchor yields NOTHING to the block - no |param|, write content directly), title, description.
- WIRING `poetry--core--popover`: values modal, open; actions close, open, openValueChanged, toggle; events poetry:popover:closed, poetry:popover:open
- WIRING `poetry--core--popper`: targets anchor, arrow, content; values align, alignOffset, anchor, anchorPoint, avoidCollisions, side, sideOffset, strategy; actions anchorPointValueChanged, reposition, setAnchor, setAnchorElement
- RULE: Use poetry_popover - never hand-roll an anchored role=dialog panel with Tailwind.
- RULE: Popover content is INTERACTIVE - for text-only hover hints use Tooltip; for pointer-only previews use HoverCard.
- RULE: Give the panel a name: use with_title (preferred) or label: - a role=dialog without a name fails the audit.
- RULE: Icon-only triggers MUST have an accessible name (the composed Button's label: rule).
- RULE: Default is NON-modal (modal: false) - reach for modal: true only when stray outside interaction would corrupt the task; reach for Dialog when the task deserves full modality.
- RULE: Critical-path panels must also be reachable without JS (full page or server-rendered open: true) - popovers are JS-required interaction.
- RULE: Do not nest a Popover inside a Popover - restructure (the layer stack allows it; comprehension does not).

## sheet (`poetry_sheet`)

Class: Poetry::Ui::Sheet::Component - BEM block `poetry-ui-sheet`.
Slot REQUIRED: with_title (the accessible name) - a call without it raises.
- `side:` (symbol) - one of top|right|bottom|left, default "right", required
- `dismissible:` (boolean) - default true
- `show_close_button:` (boolean) - default true
Slots: trigger (takes poetry_button props, not a block; with_trigger yields NOTHING to the block - no |param|, write content directly), title, description, footer.
- WIRING `poetry--core--sheet`: targets dialog; values dismissible, hotkey; actions backdropClose, close, lockScroll, open, toggle, unlockScroll
- RULE: Open sheets with with_trigger(...) - never a hand-wired button.
- RULE: with_title is REQUIRED (the accessible name) - the inherited Dialog rule.
- RULE: Pick side by content: navigation left, detail/edit right, pickers bottom.
- RULE: Do not put must-not-lose confirmations in a Sheet - that is AlertDialog.
- RULE: Do not rebuild a centered Dialog with a Sheet; use Dialog.

## tooltip (`poetry_tooltip`)

Class: Poetry::Ui::Tooltip::Component - BEM block `poetry-ui-tooltip`.
Slot REQUIRED: with_trigger (the described control) - a call without it raises.
- `align:` (symbol) - one of start|center|end, default "center"
- `content_class:` (string)
- `delay_duration:` (integer)
- `disable_hoverable_content:` (boolean)
- `label:` (string)
- `open:` (boolean) - default false
- `side:` (symbol) - one of top|right|bottom|left, default "top"
- `side_offset:` (integer) - default 0
Slots: trigger (takes poetry_button props, not a block; with_trigger yields NOTHING to the block - no |param|, write content directly).
- WIRING `poetry--core--popper`: targets anchor, arrow, content; values align, alignOffset, anchor, anchorPoint, avoidCollisions, side, sideOffset, strategy; actions anchorPointValueChanged, reposition, setAnchor, setAnchorElement
- WIRING `poetry--core--tooltip`: values delayDuration, disableHoverableContent, open; actions blurClose, clickClose, focusOpen, openValueChanged, pointerDown, pointerLeave, pointerMove; events poetry:tooltip:closed, poetry:tooltip:open
- RULE: Use poetry_tooltip - never hand-roll title-attribute replacements or hover divs.
- RULE: Tooltip content is TEXT and never interactive/focusable - links, buttons, or inputs inside are a contract violation (use Popover).
- RULE: Never put essential information only in a tooltip - touch users NEVER see it (no long-press path, by design).
- RULE: The tooltip DESCRIBES; it never names. Icon-only triggers still require label: on the composed Button.
- RULE: Wrap toolbar/button rows in ONE poetry_tooltip_provider so the warm grace makes the row feel continuous.
- RULE: Rich visual content needs label: (the plain-text announcement).
- RULE: Do not pin tooltips open as onboarding callouts - that is a Popover.

