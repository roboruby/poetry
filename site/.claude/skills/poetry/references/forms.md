# poetry forms components

Contracts generated from the registry. `RULE` lines are constraints,
not suggestions. Options are keywords; content is the block.

## button (`poetry_button`)

Triggers an action or event, such as submitting a form or opening a dialog.

Class: Poetry::Ui::Button::Component - BEM block `poetry-ui-button`.
REQUIRED - one of a content block / with_leading / with_trailing / loading: (nothing visible renders without one - label: is only the accessible name); a call satisfying none raises.
- `size:` (symbol) - one of default|xs|sm|lg|icon|icon-xs|icon-sm|icon-lg, default "default", required
- `variant:` (symbol) - one of default|destructive|outline|secondary|ghost|link, default "default", required
- `disabled:` (boolean) - default false
- `href:` (string)
- `label:` (string)
- `loading:` (boolean) - default false
- `tag:` (symbol) - one of button|a, default "button"
- `type:` (symbol) - one of button|submit|reset, default "button"
Slots: leading, trailing.
- PART `button` - The rendered control itself (<button>, or <a> when tag: :a) - every visual state rides here | states: data-variant=default|destructive|outline|secondary|ghost|link (always - the resolved variant); data-size=default|xs|sm|lg|icon|icon-xs|icon-sm|icon-lg (always - the resolved size); data-loading (loading: is set (aria-busy rides along))
- PART `icon` - Wrapper span around leading/trailing slot content - sizes and centers whatever it holds
- PART `label` - The content block's span (display: contents - children join the root's flex row directly)
- PART `spinner` - The loading indicator, swapped in for the leading icon while loading:
In blocks: `action-bar`, `app-shell`, `data-index`, `destructive-panel`, `page-header`, `stepper`, `top-nav` - for a screen, start from the block (MCP compose/describe_block, or `bin/rails g poetry:block`), not from scratch.
- RULE: Use poetry_button - never a raw <button> with hand-written Tailwind.
- RULE: The visible text is the content block: poetry_button { "Save" }. label: is ONLY the accessible name.
- RULE: Icon-only buttons (size: :icon*) MUST pass label: (the accessible name).
- RULE: Link-styled actions use variant: :link - not <a> with button classes.
- RULE: Loading via loading: - never a manual disabled + spinner.
- RULE: Never nest an interactive element inside a Button.
- RULE: Pick the variant by intent; one primary (default) action per view.

## button_group (`poetry_button_group`)

Visually joins adjacent buttons and controls into one group.

Class: Poetry::Ui::ButtonGroup::Component - BEM block `poetry-ui-button_group`.
Content block REQUIRED (its member controls) - a blockless call raises.
- `orientation:` (symbol) - one of horizontal|vertical, default "horizontal", required
- PART `button-group` - The role=group root - its selectors join ANY data-slot children into the segmented unit | states: data-orientation=horizontal|vertical (the join axis)
- PART `button-group-text` - A non-button member (the poetry_button_group_text helper's div) - a text affix joined like a button
In blocks: `data-index` - for a screen, start from the block (MCP compose/describe_block, or `bin/rails g poetry:block`), not from scratch.
- RULE: Members go in the content block - the group's selectors join ANY data-slot children (buttons, inputs, select triggers); never hand-round the inner corners.
- RULE: Give the group an aria-label when the page has more than one (role=group is unnamed by default).
- RULE: A visual divider between members is poetry_button_group_separator, not a styled border.

## calendar (`poetry_calendar`)

A month grid for selecting single dates or ranges.

Class: Poetry::Ui::Calendar::Component - BEM block `poetry-ui-calendar`.
- `mode:` (symbol) - default "single"
- `name:` (string)
- `week_start:` (integer) - default 0
- PART `calendar` - Root wrapper - the calendar controller (navigation, selection, roving arrow keys) rides here
- PART `calendar-nav` - The header row - previous/next month Buttons around the caption
- PART `calendar-caption` - The month label ('July 2026') - the controller rewrites it on navigation from the localized month names
- PART `calendar-grid` - The role=grid - the weekday header row plus six week rows (42 cells, always full weeks)
- PART `calendar-weekdays` - The role=row of weekday column headers
- PART `calendar-weekday` - One role=columnheader two-letter day label
- PART `calendar-week` - One role=row of seven day cells
- PART `calendar-day-cell` - The role=gridcell wrapper - aria-selected lives HERE (the ARIA grid contract; it is not valid on the button)
- PART `calendar-day` - One day <button> - the selection vocabulary and the roving tab stop ride here | states: data-date (always - the day's ISO date (the controller's selection key)); data-selected (the day is the single-mode pick, or a start-only range pick (bare; a complete range wears the range-* trio instead)); data-range-start (the day starts a COMPLETE range); data-range-end (the day ends a COMPLETE range); data-range-middle (the day sits strictly inside a complete range); data-today (the day is today (aria-current=date rides along)); data-outside (the day belongs to a neighbouring month (leading/trailing fill))
- PART `calendar-day-label` - The day-number span inside the button
- WIRING `poetry--core--calendar`: targets caption, day, endInput, grid, input, startInput; values max, min, mode, month, monthNames, rangeEnd, rangeStart, selected, weekStart; actions keydown, nextMonth, previousMonth, select; events poetry--core--calendar:change
- RULE: name: makes it a form control (the chosen date posts as an ISO string in a hidden input; range mode posts name[start] + name[end]).
- RULE: month:/selected:/today accept a Date or an ISO string; min:/max: bound the selectable range.
- RULE: mode: :range selects a span - selected: takes a Date..Date Range, [start, end], or {start:, end:}; the second click completes, click-before-start swaps, re-click clears.
- RULE: The grid is server-rendered - it shows a valid month with no JS; the controller adds navigation + selection.
- RULE: For a text-field + popover, use DatePicker (it composes this) - a bare Calendar is the always-visible grid.

## checkbox (`poetry_checkbox`)

A control for toggling a single value on or off.

Class: Poetry::Ui::Checkbox::Component - BEM block `poetry-ui-checkbox`.
- `checked:` (checked_state) - default false
- `disabled:` (boolean) - default false
- `label:` (string)
- `name:` (string)
- `required:` (boolean) - default false
- `unchecked_value:` (string) - default "0"
- `value:` (string) - default "1"
- PART `checkbox` - The visual button[role=checkbox] - reflects the hidden input via aria-checked plus the checked triple | states: data-checked (checked (the controller reflects every toggle here, aria-checked in step)); data-unchecked (unchecked - the indicator goes invisible); data-indeterminate (checked: :indeterminate (server/programmatic only; the first toggle resolves it to checked))
- PART `checkbox-indicator` - Centering span around the check glyph (minus when indeterminate) - CSS-hidden while unchecked, never unmounted | states: data-checked (mirrors the control (the controller reflects state on every part wearing the triple)); data-unchecked (mirrors the control - the indicator is invisible); data-indeterminate (mirrors the control - the glyph swaps to minus)
- WIRING `poetry--core--checked`: values inputId; actions check, set, toggle, uncheck; events poetry--core--checked:change
- RULE: Use poetry_checkbox (or f.check_box) - never a raw input[type=checkbox] with hand-written Tailwind, and never a hand-rolled button[role=checkbox].
- RULE: Always give it a name: in forms - a checkbox without one submits nothing (visual-only mode is for controlled UI like DataTable row selection ONLY).
- RULE: Every checkbox needs an accessible name: a Label/Field for= association (preferred) or label:.
- RULE: Indeterminate is set programmatically/server-side only - no user gesture produces it; use it for select-all parents.
- RULE: Instant-effect settings use Switch; pressed UI tools use Toggle; one-of-N uses RadioGroup.
- RULE: NEVER write the checked attributes (data-checked/data-unchecked/data-indeterminate) without aria-checked and the input's checked property (the controller writes all three; agents patching DOM must too).
- RULE: Don't suppress unchecked_value unless using the array idiom - an unchecked box that submits nothing silently keeps the old server value.

## combobox (`poetry_combobox`)

A text input with an autocomplete popover for picking from a list.

Class: Poetry::Ui::Combobox::Component - BEM block `poetry-ui-combobox`.
Slot REQUIRED: with_item (at least one item) - a call without it raises.
- `align:` (symbol) - one of start|center|end, default "start"
- `avoid_collisions:` (boolean) - default true
- `dir:` (symbol) - one of ltr|rtl
- `disabled:` (boolean) - default false
- `filter:` (boolean) - default true
- `id:` (string)
- `loop:` (boolean) - default false
- `modal:` (boolean) - default false
- `multiple:` (boolean) - default false
- `name:` (string)
- `open:` (boolean) - default false
- `placeholder:` (string)
- `required:` (boolean) - default false
- `search_placeholder:` (string)
- `side:` (symbol) - one of top|right|bottom|left, default "bottom"
- `side_offset:` (integer) - default 4
- `value:` (string)
- `width:` (string) - default "w-50"
Slots: trigger, empty, items (many; types item|group|separator - one with_<type> setter each, options as keywords).
- PART `combobox` - Root wrapper carrying both controllers (combobox + popper) and the optional dir attribute
- PART `combobox-native` - The visually-hidden native <select> - the serialization truth (Select's decision verbatim); plumbing, never styled or targeted
- PART `combobox-trigger` - The role=combobox button (the demo's outline Button) the field label reaches - value display and chevrons ride inside | states: data-placeholder (no option is committed (bare; the controller toggles it on every commit)); data-popup-open (the popup is open (bare while open, absent while closed - the controller flips it with the open state))
- PART `combobox-value` - The value display span - the selected option's label, or the placeholder | states: data-placeholder (placeholder: is given - carries the placeholder text so the controller can restore it)
- PART `combobox-content` - The popper-positioned popup housing the embedded Command anatomy - open/closed and the resolved placement ride here | states: data-open (popup is open (the controller flips the pair at runtime)); data-closed (popup is closed or animating out (the server-rendered state)); data-side=top|right|bottom|left (the placement side - server-rendered from side:, rewritten to the resolved side by popper on open); data-align=start|center|end (the placement alignment - server-rendered from align:, rewritten by popper on open) | vars: --transform-origin (popper - the animation origin matching the resolved placement); --available-width (popper - viewport space available to the popup post-flip); --available-height (popper - viewport space available to the popup post-flip); --anchor-width (popper - the trigger's measured width (the popup width tracks it - one knob, two surfaces)); --anchor-height (popper - the trigger's measured height)
- PART `command` - The embedded engine root - Command's anatomy rendered here against its own controller (composition at the markup contract)
- PART `command-input-wrapper` - The input row - search icon + filter input above the list
- PART `command-search-icon` - Decorative search glyph beside the input
- PART `command-input` - The filter input (role=combobox) - the typing session and aria-activedescendant live here. Single: in the popup with its own accessible name; multiple: INLINE in the chips frame (Base UI's input-inside layout), where the field label reaches it | states: data-popup-open (multiple: the popup is open (bare while open, absent while closed - the input carries the flip; single's trigger owns it))
- PART `command-list` - THE role=listbox - the aria-controls target of both combobox roles
- PART `command-empty` - Zero-matches message - rendered hidden; the engine unhides it when the filter pass leaves no visible items
- PART `command-group` - role=group labelled by its heading - hidden by the engine when every member item is filtered out
- PART `command-group-heading` - The group heading - styled, no ARIA role (the group points at it via aria-labelledby)
- PART `command-item` - One role=option div wearing BOTH meanings - a Command item (filtering + highlight) AND Select's committed-value surface | states: data-value (always - the option's committable value (the native <option> twin)); data-selected (the option is committed (bare; absent while unselected - the controller twin-writes it with aria-selected)); data-highlighted (the item holds the activedescendant highlight (the server seeds it; the engine moves it with the input's aria-activedescendant)); data-disabled (disabled: is set (aria-disabled rides along)); data-hidden (the filter scored the item zero (the engine pairs it with hidden; never rendered server-side))
- PART `command-item-text` - The option's label span - the filter/typematch text source
- PART `combobox-item-indicator` - The trailing committed-value check (ms-auto per the demo) - the parent item's data-selected absence hides it
- PART `command-separator` - role=separator divider - hidden by the engine whenever the query is non-empty
- PART `command-status` - The engine's sr-only polite result-count live region | states: data-zero (always - the localized zero-results template); data-one (always - the localized one-result template); data-other (always - the localized many-results template (a literal count placeholder the controller interpolates))
- PART `combobox-chips` - The chips FIELD frame (multiple: only) - the popper anchor replacing the trigger; chips + the inline input flex-wrap inside, and role=toolbar rides it only while it holds >=1 chip | states: data-placeholder (the selection is empty (bare; the controller flips it on every commit - the toolbar role departs with it)); data-disabled (disabled: is set - every chip mutation is gated); data-remove-label (always - the localized chip-remove template (a literal label placeholder the controller interpolates for client-built chips))
- PART `combobox-chip` - One committed value (multiple: only) - a div taking REAL focus (tabindex=-1, styled by :focus-visible; chips NEVER wear data-highlighted), named by its value text, holding the remove button | states: data-value (always - the chip's committed value (the native <option> twin)); data-disabled (disabled: is set (chip focus is blocked entirely))
- PART `combobox-chip-remove` - The chip's native remove button (tabindex=-1, labelled 'Remove <label>') - a press removes the value and is never a chips-area press
- WIRING `poetry--core--combobox`: values modal, multiple, open, value; actions chipKeydown, chipsPointerdown, close, inputKeydown, nativeChanged, open, openValueChanged, removeChip, setValue, toggle, triggerKeydown, valueValueChanged; events poetry:combobox:change, poetry:combobox:closed, poetry:combobox:open, poetry:combobox:select
- WIRING `poetry--core--command`: values debounce, filter, loop; actions activate, filterInput, highlightItem, keydown, pointerHighlight, reset; events poetry:command:filter, poetry:command:highlight, poetry:command:select
- WIRING `poetry--core--popper`: targets anchor, arrow, content; values align, alignOffset, anchor, anchorPoint, avoidCollisions, side, sideOffset, strategy; actions anchorPointValueChanged, reposition, setAnchor, setAnchorElement
- RULE: Use poetry_combobox (f.poetry_combobox in forms) - never hand-wire Popover+Command+hidden-input; this component IS that wiring, with the form story done right.
- RULE: Combobox picks VALUES. Filter-then-ACT is bare Command; short known lists are Select; free text is Input.
- RULE: Every Combobox MUST be named (Field label via id: or aria-label) - a nameless bare combobox fails at render.
- RULE: NEVER write aria-selected from highlight logic (position is data-highlighted + aria-activedescendant); NEVER write the display without the native select first - the commit pipeline does all of it; agents patching DOM must too.
- RULE: Async options: filter: false + the Turbo-frame ?q= recipe - AND the frame must render the twin native <option> for every committable item (the recipe's one hard rule).
- RULE: multiple: true is the multi-select/chips mode: value: takes an ARRAY, the native <select multiple> posts name[] (the [] is appended for you), selection TOGGLES with the popup staying open, and chips replace the trigger - never fake multi with hidden inputs.
- RULE: Do not put interactive elements inside options (an option IS the interactive unit).
- RULE: Deselection in single mode is include_blank (a visible blank option), never a re-click toggle - committing the already-selected value closes without change. In multiple, re-committing IS the deselect gesture (chip-remove is its pointer twin).

## date_field (`poetry_date_field`)

A segmented input for typing a date one part at a time.

Class: Poetry::Ui::DateField::Component - BEM block `poetry-ui-date_field`.
- `described_by:` (string)
- `disabled:` (boolean) - default false
- `id:` (string)
- `invalid:` (boolean) - default false
- `label:` (string)
- `locale:` (string)
- `max:` ()
- `min:` ()
- `name:` (string) - required
- `placeholder_value:` ()
- `readonly:` (boolean) - default false
- `required:` (boolean) - default false
- `value:` ()
- PART `date-field` - Root - the controller and the enhanced/disabled surface ride here | states: data-enhanced (the controller connected and built segments (no JS = the native input, visible and styled)); data-disabled (disabled: is set); data-invalid (invalid: is set (the group wears the destructive ring))
- PART `date-field-group` - The bordered segment row (cn-input chrome, focus-within ring) - hidden until enhancement, then the editing surface the controller fills with segments | states: data-disabled (disabled: is set (chrome dims, pointer events off)); data-invalid (invalid: is set (destructive border + ring))
- PART `date-field-input` - The native <input type=date> - THE form value in both modes; tabindex -1 + aria-hidden once segments exist
- WIRING `poetry--core--date-field`: targets group, input; values hourCycle, labels, locale, placeholder, placeholders, seconds; actions focusGap, settle; events poetry:date-field:change
- RULE: Date entry is a DateField (poetry_date_field / form.date_field) - never a masked Input, three selects, or a bare input type=date when the design system is in play.
- RULE: The native input is the form value: params[<name>] is ISO (yyyy-mm-dd) with or without JS; min:/max: take Date or ISO strings and ride native validation.
- RULE: Pair with a Label/Field for the accessible name (label for= the input id); standalone use takes label: - segments announce it themselves.
- RULE: Locale drives segment order and numerals automatically; pass locale: only to pin a field to a different locale than the page.

## date_picker (`poetry_date_picker`)

A date field that opens a calendar popover for selection.

Class: Poetry::Ui::DatePicker::Component - BEM block `poetry-ui-date_picker`.
- `label:` (string)
- `mode:` (symbol) - default "single"
- `name:` (string) - required
- `placeholder:` (string) - default "Pick a date"
- PART `date-picker` - Root wrapper - the glue controller (formats the trigger label, closes on pick) around the composed Popover + Calendar
- WIRING `poetry--core--date-picker`: targets label; values locale, mode, placeholder; actions picked
- RULE: name: is REQUIRED - the chosen date posts as an ISO string (the Calendar's hidden input).
- RULE: value: preselects a date (a Date or ISO string) - the trigger shows it formatted, no JS needed.
- RULE: min:/max: bound the selectable range; the label + placeholder are the trigger's text.
- RULE: For an always-visible grid use Calendar directly - DatePicker is the field+popover form.

## field (`poetry_field`)

Wraps a form control with its label, hint, and validation message.

Class: Poetry::Ui::Field::Component - BEM block `poetry-ui-field`.
- `orientation:` (symbol) - one of vertical|horizontal, default "vertical", required
- `error:` (string)
- `group:` (boolean) - default false
- `hint:` (string)
- `id:` (string) - required
- `label_text:` (string)
- `required:` (boolean) - default false
- PART `field` - The quartet's grid root - label, control, hint, and error stack inside | states: data-invalid=true|false (always - true when error: is present, else false); data-orientation=vertical|horizontal (always - the resolved orientation (horizontal is the boolean-control layout))
- PART `field-hint` - The hint <p> - its id lands in the control's aria-describedby
- PART `field-error` - The error <p> - present only when error: is set; its id leads the control's aria-describedby
- PART `checkbox-input` - A nested Checkbox's hidden native input - the toggle renders as a wrapper-free fragment, so its sibling form store sits directly in the field's DOM (the horizontal boolean-control layout)
- RULE: Wire the control with field.control_attributes - never hand-write aria-describedby.
- RULE: Error text arrives via error: (from model errors upstream) - never a bare red <p>.
- RULE: orientation: :horizontal is the boolean-control layout (checkbox/switch left, label + hint stacked right) - text inputs and groups stay vertical.

## file_input (`poetry_file_input`)

A control for selecting, previewing, and removing files to upload.

Class: Poetry::Ui::FileInput::Component - BEM block `poetry-ui-file_input`.
- `variant:` (symbol) - one of input|dropzone, default "input"
- `accept:` (string)
- `described_by:` (string)
- `disabled:` (boolean) - default false
- `hint:` (string)
- `id:` (string)
- `invalid:` (boolean) - default false
- `multiple:` (boolean) - default false
- `name:` (string)
- `prompt:` (string)
- PART `file-input` - The dropzone root - wraps the zone, the selection list, and clear | states: data-variant=dropzone (always on the dropzone root (the input variant renders the Input component instead)); data-dragging (a file drag is over the zone (controller-written, enter/leave counted)); data-populated (the native input holds at least one file (controller-written))
- PART `file-input-dropzone` - The <label> drop surface - dashed, platform click-to-browse; its text is the control's accessible name
- PART `file-input-control` - The native <input type=file> - visually hidden in the dropzone, THE form value in both variants
- PART `file-input-prompt` - The zone's instruction line (prompt: overrides the default)
- PART `file-input-hint` - Muted constraints copy under the prompt (hint: - formats, size)
- PART `file-input-list` - The selected-file <ul> the controller fills (name + size per item; items are controller-built, not server parts)
- PART `file-input-clear` - The clear affordance - hidden until populated; never re-opens the picker
- WIRING `poetry--core--file-input`: targets clear, input, list; values multiple; actions changed, clear, dragenter, dragleave, dragover, drop; events poetry:file-input:change
- RULE: File selection is a FileInput: variant: :input for compact forms, :dropzone when dragging is expected (uploads as the page's point) - never a hand-rolled drop div.
- RULE: The native input is the form value: set name: (multiple: true wants a name ending in [] for Rails params); ActiveStorage direct upload attaches to it as usual.
- RULE: The dropzone's selected-file list and clear button are controller-rendered - compose prompt:/hint: copy instead of adding your own list markup.
- RULE: In a Field, prefer form.file_input (the builder wires id/label/errors); the bare component suits standalone dropzones.

## input (`poetry_input`)

A form control for entering a single line of text.

Class: Poetry::Ui::Input::Component - BEM block `poetry-ui-input`.
- `disabled:` (boolean) - default false
- `invalid:` (boolean) - default false
- `mask:` (string)
- `name:` (string)
- `placeholder:` (string)
- `type:` (string) - default "text"
- `value:` (string)
- PART `input` - The <input> element itself - no inner anatomy; error state is aria-invalid (set by Field/FormBuilder), never a parallel class | states: data-raw (mask: is set - the unmasked value, kept live by the mask controller (the masked text is what submits))
- WIRING `poetry--core--mask`: values alwaysShowMask, autoClear, mask, showMaskOnFocus, slotChar, upcase; events poetry:mask:change, poetry:mask:complete
- RULE: Inside a form, never render Input directly - use the FormBuilder's field (it wires ids, errors, and aria).
- RULE: Error styling comes from aria-invalid, set from model errors - never hand-toggle error classes.
- RULE: mask: formats as the user types ('(999) 999-9999'; 9=digit, a=letter, A=upper, *=alnum, #=sign/digit, \\ escapes, ? makes the rest optional) - the MASKED text submits; read data-raw for the bare value.

## input_group (`poetry_input_group`)

One bordered surface combining an input with buttons, icons, or add-ons.

Class: Poetry::Ui::InputGroup::Component - BEM block `poetry-ui-input_group`.
Content block REQUIRED (its control + addons) - a blockless call raises.
- PART `input-group` - The bordered group surface (role=group) - wears the border, the focus-within ring, and the invalid ring for the borderless control inside
- PART `input-group-addon` - One addon cell (icons, text, kbd hints, tiny buttons) rendered by poetry_input_group_addon around the control | states: data-align=inline-start|inline-end|block-start|block-end (always - the addon's align: axis (inline rides the row, block takes a full-width row))
In blocks: `data-index` - for a screen, start from the block (MCP compose/describe_block, or `bin/rails g poetry:block`), not from scratch.
- RULE: The control INSIDE must be poetry_input_group_input/_textarea - a plain poetry_input keeps its own border+ring and double-chromes the group.
- RULE: Addons are poetry_input_group_addon(align:) wrapping icons/text/buttons; use poetry_input_group_text for muted captions and poetry_input_group_button for tiny actions.
- RULE: The group is a surface, not a label - the control still needs its Label/Field pairing.

## input_otp (`poetry_input_otp`)

A fixed-length, segmented input for one-time passcodes.

Class: Poetry::Ui::InputOtp::Component - BEM block `poetry-ui-input_otp`.
- `disabled:` (boolean) - default false
- `groups:` ()
- `invalid:` (boolean) - default false
- `length:` (integer) - required
- `name:` (string) - required
- `pattern:` () - default "digits"
- `required:` (boolean) - default false
- `separator:` (boolean) - default true
- `value:` (string)
- PART `input-otp-container` - Root row (forced dir=ltr - slot order equals string index order even on RTL pages) wrapping the real input and the mirror cells
- PART `input-otp` - THE real native <input> (autocomplete one-time-code) stretched invisibly over the row - the only AT and serialization surface
- PART `input-otp-group` - One aria-hidden cluster of mirror cells (groups: clustering)
- PART `input-otp-slot` - One presentational mirror cell - paints its char and the active-cell ring | states: data-active=true|false ("true" while the native caret sits on this cell (the controller projects selectionStart while the input is focused; the server renders "false"))
- PART `input-otp-caret` - The fake-caret overlay - hidden server-side; the controller unhides it on the active EMPTY cell
- PART `input-otp-separator` - The between-groups dash - role=separator kept for parity but aria-hidden (a recorded divergence)
- WIRING `poetry--core--otp`: targets input, slot; values length, pattern; actions focusInput, paste, sync; events poetry:otp:change, poetry:otp:complete
- RULE: Use poetry_input_otp / form.otp_field - NEVER build per-cell inputs (n Tab stops, broken paste, broken SMS autofill, unnameable cells).
- RULE: Label via Field always ('Verification code'); put the length in the hint.
- RULE: groups must sum to length (ArgumentError).
- RULE: Do NOT auto-submit on poetry:otp:complete without a visible confirm affordance - silent submit on the 6th keystroke strands users who mistyped char 3.
- RULE: Never pre-fill value: with a real code in previews/test fixtures beyond dummies; never log the value (it is a live credential).
- RULE: InputOTP is for CODES - passwords use Input type=password, longer identifiers use Input.

## label (`poetry_label`)

An accessible caption bound to a form control.

Class: Poetry::Ui::Label::Component - BEM block `poetry-ui-label`.
- `for_id:` (string)
- PART `label` - The <label> element itself - for= rides it (dropped in group mode, where the group names itself via aria-labelledby at this label's id)
In blocks: `data-index` - for a screen, start from the block (MCP compose/describe_block, or `bin/rails g poetry:block`), not from scratch.
- RULE: Every control gets a Label wired via for_id - placeholder text is never the label.

## native_select (`poetry_native_select`)

A styled wrapper around the real native select control.

Class: Poetry::Ui::NativeSelect::Component - BEM block `poetry-ui-native_select`.
- `disabled:` (boolean) - default false
- `id:` (string)
- `invalid:` (boolean) - default false
- `label:` (string)
- `name:` (string)
- `size:` (symbol) - one of default|sm, default "default"
- PART `native-select-wrapper` - Relative shell around the select and the chevron - dims the pair when the select is disabled | states: data-size=default|sm (always - the resolved size)
- PART `native-select` - The real <select> - appearance-none (the chevron replaces the native arrow); platform picker and form submission stay native | states: data-size=default|sm (always - the resolved size (mirrors the wrapper))
- PART `native-select-icon` - The decorative chevron wrapper - absolutely pinned, aria-hidden
- PART `native-select-option` - An <option> from the options: fast path (or poetry_native_select_option) - Canvas system colors keep the native dropdown legible
In blocks: `data-index` - for a screen, start from the block (MCP compose/describe_block, or `bin/rails g poetry:block`), not from scratch.
- RULE: This is a REAL <select> - use it for plain picking; the JS Select is for styled options.
- RULE: Pair it with a Label (for_id: its id) or a Field - a bare select has no accessible name.
- RULE: The fast path is options: [[label, value], ...] + selected:; a content block overrides it.

## number_field (`poetry_number_field`)

A numeric input with increment and decrement steppers.

Class: Poetry::Ui::NumberField::Component - BEM block `poetry-ui-number_field`.
- `described_by:` (string)
- `disabled:` (boolean) - default false
- `format:` ()
- `id:` (string)
- `invalid:` (boolean) - default false
- `label:` (string)
- `large_step:` (float) - default 10.0
- `locale:` (string)
- `max:` (float)
- `min:` (float)
- `name:` (string) - required
- `placeholder:` (string)
- `readonly:` (boolean) - default false
- `required:` (boolean) - default false
- `small_step:` (float) - default 0.1
- `snap:` (boolean) - default false
- `step:` (float) - default 1.0
- `value:` ()
- `wheel:` (boolean) - default false
- PART `number-field` - Root wrapper - the controller, disabled/invalid/filled state, and the two-input pair ride here | states: data-disabled (disabled: is set (steppers disable, the group chrome dims)); data-invalid (invalid: is set (the group wears the destructive ring via the control's aria-invalid)); data-filled (the value is non-null (the controller keeps it live))
- PART `number-field-group` - The bordered field surface - wears InputGroup's chrome (cn-input-group), focus ring keyed on the control inside
- PART `input-group-addon` - The two stepper cells - InputGroup's addon vocabulary, reused so the group paddings compose | states: data-align=inline-start|inline-end (always - inline-start holds the decrement, inline-end the increment)
- PART `input-group-control` - The visible formatted <input type=text> - InputGroup's control slot (the themes' focus-ring hook); aria-roledescription "Number field", never a spinbutton
- WIRING `poetry--core--number-field`: targets decrement, hidden, increment, input; values format, largeStep, locale, max, min, smallStep, snap, step, wheel; actions blur, focus, hiddenChanged, input, keydown, leave, press, tap; events poetry:number-field:change, poetry:number-field:commit
- RULE: Use poetry_number_field / form.number_field - never a hand-rolled spinner or a bare input type=number.
- RULE: The server reads params[<name>] as the raw number string - display formatting (format:) never changes what submits.
- RULE: Steppers are mouse/touch affordances (tabindex -1); keyboard users step with ArrowUp/Down (Shift = large_step, Alt = small_step) on the input itself.
- RULE: Pair it with a Label/Field for the accessible name - the component ships none.
- RULE: format: takes Intl.NumberFormatOptions as a Hash ({ style: "currency", currency: "USD" }); pick locale: to pin parsing separators.

## radio_group (`poetry_radio_group`)

A set of options where only one can be selected at a time.

Class: Poetry::Ui::RadioGroup::Component - BEM block `poetry-ui-radio_group`.
Slot REQUIRED: with_item (at least one radio item) - a call without it raises.
- `disabled:` (boolean) - default false
- `invalid:` (boolean) - default false
- `label:` (string)
- `loop:` (boolean) - default true
- `name:` (string) - required
- `orientation:` (symbol) - one of both|vertical|horizontal, default "both"
- `required:` (boolean) - default false
- `value:` (string)
Slots: items (many).
- PART `radio-group` - The role=radiogroup root - one Tab stop; items (and their label-pairing rows) render as direct children | states: data-disabled (disabled: is set on the root - every item disables with it)
- PART `radio-group-item` - A button[role=radio] per item - carries its own hidden native radio as a sibling | states: data-checked (the checked item (the controller writes the pair and aria-checked together on every item)); data-unchecked (every other item); data-disabled (the item (or the whole group) is disabled - also the roving-focus collection filter); data-value (always - the item's value (keys the checked-value machine))
- PART `radio-group-indicator` - Centering span holding the checked dot - hidden (the native attribute, toggled by the controller) while unchecked
- WIRING `poetry--core--radio-group`: targets input; values value; actions check, entryCheck, setValue, valueValueChanged; events poetry:radio-group:change
- WIRING `poetry--core--roving-focus`: values loop, manageTabindex, orientation; actions keydown; events poetry--core--roving-focus:entry
- RULE: Use poetry_radio_group / form.radio_group - never hand-roll role=radio buttons.
- RULE: Every item MUST have a unique value: (ArgumentError on duplicates).
- RULE: The GROUP must be labelled - label: (or aria-labelledby) - an unlabelled radiogroup is an APG violation (ArgumentError).
- RULE: Pair every item with a visible label (item label: renders the Label for= pairing) - a bare dot is not an option.
- RULE: NEVER write the checked attributes (data-checked/data-unchecked) without aria-checked (the controller writes both; agents patching DOM must too).
- RULE: Do not use RadioGroup for navigation or immediate actions; checking must not submit or navigate by itself.
- RULE: 7+ options: use Select instead.
- RULE: Wire errors through Field/FormBuilder (invalid: + describedby on the root) - never a bare red ring.

## search_field (`poetry_search_field`)

A search input with clear and search affordances.

Class: Poetry::Ui::SearchField::Component - BEM block `poetry-ui-search_field`.
- `described_by:` (string)
- `disabled:` (boolean) - default false
- `id:` (string)
- `invalid:` (boolean) - default false
- `label:` (string)
- `name:` (string) - required
- `placeholder:` (string)
- `readonly:` (boolean) - default false
- `required:` (boolean) - default false
- `value:` (string)
- PART `search-field` - Root - the controller and the emptiness state ride here | states: data-empty (the input holds no text (server-set, controller-kept; hides the clear affordance))
- PART `input-group-addon` - The leading search-glyph cell - InputGroup's addon vocabulary (the NumberField precedent) | states: data-align=inline-start|inline-end (always - inline-start holds the glyph, inline-end the clear button)
- PART `search-field-group` - The bordered field surface - InputGroup's chrome, focus ring keyed on the control inside
- PART `input-group-control` - The native <input type=search> - InputGroup's control slot (the themes' focus-ring hook); WebKit's own cancel affordance suppressed
- WIRING `poetry--core--search-field`: targets clear, input; actions changed, clear, holdFocus, keydown; events poetry:search-field:clear
- RULE: Search inputs are a SearchField (poetry_search_field) - never a bare Input with a hand-rolled clear button; Escape-clears and focus retention ride the controller.
- RULE: Enter submits the surrounding form natively - wrap it in a form/turbo-frame for live search; listen for poetry:search-field:clear to reset results.
- RULE: Pair with a Label/Field for the accessible name, or pass label: standalone.

## select (`poetry_select`)

A dropdown for choosing one option from a list.

Class: Poetry::Ui::Select::Component - BEM block `poetry-ui-select`.
Slot REQUIRED: with_item (at least one item) - a call without it raises.
- `align:` (symbol) - one of start|center|end, default "start"
- `align_item_with_trigger:` (boolean) - default false
- `avoid_collisions:` (boolean) - default true
- `dir:` (symbol) - one of ltr|rtl
- `disabled:` (boolean) - default false
- `id:` (string)
- `loop:` (boolean) - default false
- `modal:` (boolean) - default true
- `name:` (string)
- `open:` (boolean) - default false
- `placeholder:` (string)
- `required:` (boolean) - default false
- `side:` (symbol) - one of top|right|bottom|left, default "bottom"
- `side_offset:` (integer) - default 4
- `size:` (symbol) - one of sm|default, default "default"
- `value:` (string)
Slots: trigger, items (many; types item|group|separator - one with_<type> setter each, options as keywords).
- PART `select` - Root wrapper carrying both controllers (select + popper) and the optional dir attribute
- PART `select-native` - The visually-hidden native <select> - the serialization truth (name/required/disabled + every option); plumbing, never styled or targeted
- PART `select-trigger` - The role=combobox button the field label reaches - the value display and chevron ride inside | states: data-size=sm|default (always - the resolved size variant); data-placeholder (no option is committed (bare; the controller toggles it on every commit)); data-popup-open (the popup is open (bare while open, absent while closed - the controller flips it with the open state))
- PART `select-value` - The value display span - the selected option's label, or the placeholder | states: data-placeholder (placeholder: is given - carries the placeholder text so a later clear can restore it)
- PART `select-content` - The popper-positioned popup shell (scroll buttons + viewport) - open/closed and the resolved placement ride here | states: data-open (popup is open (the controller flips the pair at runtime)); data-closed (popup is closed or animating out (the server-rendered state)); data-side=top|right|bottom|left (the placement side - server-rendered from side:, rewritten to the resolved side by popper on open); data-align=start|center|end (the placement alignment - server-rendered from align:, rewritten by popper on open) | vars: --transform-origin (popper - the animation origin matching the resolved placement); --available-width (popper - viewport space available to the popup post-flip); --available-height (popper - viewport space available to the popup post-flip); --anchor-width (popper - the trigger's measured width); --anchor-height (popper - the trigger's measured height); --radix-select-trigger-width (the select controller measures the trigger on open - the viewport's min-width binding); --radix-select-trigger-height (the select controller measures the trigger on open - the viewport's MINIMUM-height binding (a hard height collapses the popup to the trigger; the list grows past it))
- PART `select-scroll-up-button` - Hover-scroll affordance above the viewport - rendered always but hidden; the controller unhides it per scroll extremes (aria-hidden)
- PART `select-scroll-down-button` - Hover-scroll affordance below the viewport (the same contract as the up button)
- PART `select-viewport` - The role=listbox scroll container - the options' actual parent, labelled from the trigger
- PART `select-group` - role=group wrapper labelled by its select-label heading
- PART `select-label` - The group heading - styled, no ARIA role (the group points at it via aria-labelledby)
- PART `select-item` - One role=option div - selection, disablement, and the committable value ride here | states: data-value (always - the option's committable value (the native <option> twin)); data-selected (the option is committed (bare; absent while unselected - the controller twin-writes it with aria-selected)); data-disabled (disabled: is set (aria-disabled rides along))
- PART `select-item-indicator` - The check gutter - server-rendered always; the parent item's data-selected absence hides it
- PART `select-item-text` - The option's label span - the value display copies from it
- PART `select-separator` - Decorative divider between options (aria-hidden)
- WIRING `poetry--core--popper`: targets anchor, arrow, content; values align, alignOffset, anchor, anchorPoint, avoidCollisions, side, sideOffset, strategy; actions anchorPointValueChanged, reposition, setAnchor, setAnchorElement
- WIRING `poetry--core--select`: values alignItemWithTrigger, loop, modal, open, typeaheadTimeout, value; actions close, commit, keydown, nativeChanged, open, openValueChanged, scrollHoldStart, scrollHoldStop, setValue, syncScrollButtons, toggle, triggerKeydown, valueValueChanged; events poetry:select:change, poetry:select:closed, poetry:select:open, poetry:select:select
- RULE: Use poetry_select (f.poetry_select in forms) - never hand-roll role=listbox popups, and never fake a select with DropdownMenu radio items bound to a hidden field.
- RULE: Options are VALUES. If activating an option should DO something beyond setting a value, it's a DropdownMenu item.
- RULE: In forms, ALWAYS go through f.poetry_select - it wires name/id/value/errors/required; bare poetry_select in a form is a smell.
- RULE: Every Select MUST be named: a Field label (id: + label[for]) or aria-label. A bare unnamed select fails at render - do not suppress it.
- RULE: NEVER write aria-selected without its data-selected twin, and NEVER write the display text without writing the native select's value first - the controller does all three; agents patching DOM must too.
- RULE: Do not put interactive elements inside options (an option IS the interactive unit).
- RULE: Long/filterable/async lists or multi-select -> Combobox, not a 50-option Select; 2-4 options -> RadioGroup.
- RULE: The hidden native select is plumbing - never target it with styles, labels, or Capybara selectors (drive the combobox like a user).
- RULE: Positioning is popper-only: poetry Select drops below the trigger (shadcn's item-aligned overlay mode is not ported - a documented parity delta).

## sensitive_input (`poetry_sensitive_input`)

A masked secret field with a reveal toggle and a copy button.

Class: Poetry::Ui::SensitiveInput::Component - BEM block `poetry-ui-sensitive_input`.
- `copy:` (boolean) - default false
- `described_by:` (string)
- `disabled:` (boolean) - default false
- `id:` (string)
- `invalid:` (boolean) - default false
- `label:` (string)
- `name:` (string) - required
- `placeholder:` (string)
- `readonly:` (boolean) - default false
- `required:` (boolean) - default false
- `value:` (string)
- PART `sensitive-input` - Root - the state machine rides here | states: data-state=masked|revealed|empty (always - masked (value hidden, group is the reveal button), revealed, or empty); data-copied (copy: only - stamped for a beat after a successful copy (the clipboard-text engine)); data-disabled (disabled: - the masked group loses its tab stop and pointer affordances)
- PART `sensitive-input-group` - The bordered field surface (InputGroup's chrome) - clicks anywhere on it reveal; wears the focus ring when the mask button inside holds focus
- PART `input-group-control` - The real input - rendered in every state for layout stability; inert while masked (aria-hidden, tabindex -1, readonly, transparent); type=password unless revealed
- PART `sensitive-input-mask` - The overlay painting the masked state - while masked it IS the reveal button (role=button, tabindex 0, "{label}, masked.", described by the sr hint; only text spans inside, so no nested-interactive); bullet dots swap to the reveal hint on hover/focus with no layout shift
- PART `input-group-addon` - The trailing cell holding the eye (and copy: affordance) | states: data-align=inline-end (always - inline-end holds the actions)
- WIRING `poetry--core--clipboard-text`: targets input, source; values message, text; actions copy; events poetry:clipboard-text:copied
- WIRING `poetry--core--sensitive-input`: targets hint, input, mask, toggle; values hiddenMessage, maskedLabel, readOnly; actions blurred, changed, inputKeydown, maskKeydown, reveal, toggle; events poetry:sensitive-input:mask, poetry:sensitive-input:reveal
- RULE: Secrets shown-on-demand are a SensitiveInput (poetry_sensitive_input) - never a bare password Input with a hand-rolled eye; the masked-container contract (role=button, focus discipline, blur re-mask) rides the controller.
- RULE: label: feeds the masked announcement ("{label}, masked.") - pair with a Label/Field for the visible caption.
- RULE: copy: true adds copy-without-revealing; leave it off for password-change forms.
- RULE: Values re-mask on blur BY DESIGN - do not fight it with reveal-state persistence.

## slider (`poetry_slider`)

An input for selecting a value or range along a track.

Class: Poetry::Ui::Slider::Component - BEM block `poetry-ui-slider`.
- `described_by:` (string)
- `disabled:` (boolean) - default false
- `inverted:` (boolean) - default false
- `label:` ()
- `labelled_by:` (string)
- `max:` (float) - default 100.0
- `min:` (float) - default 0.0
- `min_steps_between_thumbs:` (integer) - default 0
- `name:` (string) - required
- `orientation:` (symbol) - one of horizontal|vertical, default "horizontal"
- `step:` (float) - default 1.0
- `value:` ()
- `value_text:` ()
- `values:` ()
- PART `slider` - Root - the controller, the geometry vars, and pointer capture ride here | states: data-orientation=horizontal|vertical (always - the axis); data-disabled (disabled: is set (the control is inert; the hidden inputs still submit)); data-dragging (a pointer drag is in flight (the controller sets it for the gesture; never rendered server-side)) | vars: --slider-start (the filled range's start edge as a percentage - server-rendered (no first-paint jump), rewritten by the controller on every move); --slider-end (the filled range's end edge as a percentage (the single-thumb value rides here))
- PART `slider-track` - The full-length rail the range paints over | states: data-orientation=horizontal|vertical (always - mirrors the root)
- PART `slider-range` - The filled span between --slider-start and --slider-end | states: data-orientation=horizontal|vertical (always - mirrors the root)
- PART `slider-anchor` - Absolutely positioned thumb wrapper (one per thumb, with its hidden input alongside) seated on the geometry vars | states: data-orientation=horizontal|vertical (always - mirrors the root)
- PART `slider-thumb` - The role=slider handle - its own Tab stop, carrying the aria-value* surface (bounds neighbor-clamped in range mode) | states: data-orientation=horizontal|vertical (always - mirrors the root); data-disabled (disabled: is set (tabindex drops to -1)); data-dragging (this thumb is the one being dragged (the controller pairs it with the root's))
- WIRING `poetry--core--slider`: targets input, range, thumb, track; values inverted, max, min, minStepsBetweenThumbs, orientation, step, value; actions keydown, pointerdown, setValue, valueValueChanged; events poetry:slider:change, poetry:slider:commit
- RULE: Use poetry_slider / form.slider - never hand-roll a draggable div.
- RULE: Every thumb MUST have a distinct accessible name (label: - array of two for ranges). ArgumentError otherwise.
- RULE: Give value_text: whenever the number alone is meaningless ('$200', '80%') - SR users hear aria-valuetext.
- RULE: Range mode: values must be sorted [low, high]; use min_steps_between_thumbs to keep a meaningful gap.
- RULE: Do not use Slider for precise known-number entry (use Input type=number) or in no-JS-required forms (native input type=range).
- RULE: Debounce on poetry:slider:commit, never on :change (change fires every drag frame).
- RULE: Never transition the thumb/range position with CSS - geometry must track the pointer.

## switch (`poetry_switch`)

A toggle for turning a setting on or off.

Class: Poetry::Ui::Switch::Component - BEM block `poetry-ui-switch`.
- `size:` (symbol) - one of default|sm, default "default", required
- `checked:` (boolean) - default false
- `disabled:` (boolean) - default false
- `label:` (string)
- `name:` (string)
- `required:` (boolean) - default false
- `unchecked_value:` (string) - default "0"
- `value:` (string) - default "1"
- PART `switch` - The visual button[role=switch] - reflects the hidden input via aria-checked plus the checked pair (never indeterminate) | states: data-checked (on (the shared checked controller reflects every toggle here, aria-checked in step)); data-unchecked (off (the server-rendered default)); data-size=default|sm (always - the resolved size (the thumb reads it via group/switch selectors))
- PART `switch-thumb` - The sliding knob - travel is pure CSS off the checked pair | states: data-checked (mirrors the control (the controller reflects state on every part wearing the pair)); data-unchecked (mirrors the control - the thumb sits at the start)
- WIRING `poetry--core--checked`: values inputId; actions check, set, toggle, uncheck; events poetry--core--checked:change
- RULE: Use poetry_switch - never a styled checkbox pretending to be a switch (role=switch announces on/off; that's the point).
- RULE: Switch = instant effect; Checkbox = staged for submit. If nothing happens until a Save button, use Checkbox.
- RULE: Every switch needs an accessible name (Label/Field for= or label:).
- RULE: Switches are BINARY - no indeterminate, ever (ArgumentError). A third state means a different component.
- RULE: The instant-effect recipe pairs the flip with server persistence (Turbo auto-submit) - never flip UI-only for a setting the user believes is saved.
- RULE: NEVER write the checked attributes (data-checked/data-unchecked) without aria-checked and the input sync (the controller writes all three).

## textarea (`poetry_textarea`)

A form control for entering multiple lines of text.

Class: Poetry::Ui::Textarea::Component - BEM block `poetry-ui-textarea`.
- `disabled:` (boolean) - default false
- `invalid:` (boolean) - default false
- `name:` (string)
- `placeholder:` (string)
- `rows:` (integer)
- `value:` (string)
- PART `textarea` - The <textarea> element itself - value renders as content; auto-grow is the field-sizing-content CSS property, zero JS
- RULE: Wire through Field/FormBuilder (control_attributes) - never hand-write the aria plumbing.
- RULE: Placeholder is NOT a label - pair with Label/Field always.
- RULE: Use Textarea for free text; Input for single-line; do not bolt a JS autosizer on (auto-grow is CSS).
- RULE: Do not set native required - required flows as aria-required via Field.

## time_field (`poetry_time_field`)

A segmented input for typing a time one part at a time.

Class: Poetry::Ui::TimeField::Component - BEM block `poetry-ui-time_field`.
- `described_by:` (string)
- `disabled:` (boolean) - default false
- `hour_cycle:` (string)
- `id:` (string)
- `invalid:` (boolean) - default false
- `label:` (string)
- `locale:` (string)
- `max:` ()
- `min:` ()
- `name:` (string) - required
- `placeholder_value:` ()
- `readonly:` (boolean) - default false
- `required:` (boolean) - default false
- `seconds:` (boolean) - default false
- `value:` ()
- PART `time-field` - Root - the controller and the enhanced/disabled surface ride here (segments inside share the date-field-* vocabulary) | states: data-enhanced (the controller connected and built segments (no JS = the native input, visible and styled)); data-disabled (disabled: is set); data-invalid (invalid: is set (the group wears the destructive ring))
- PART `time-field-group` - The bordered segment row - hidden until enhancement, then the editing surface (cn-input chrome, focus-within ring) | states: data-disabled (disabled: is set (chrome dims, pointer events off)); data-invalid (invalid: is set (destructive border + ring))
- PART `time-field-input` - The native <input type=time> - THE form value in both modes; tabindex -1 + aria-hidden once segments exist
- WIRING `poetry--core--date-field`: targets group, input; values hourCycle, labels, locale, placeholder, placeholders, seconds; actions focusGap, settle; events poetry:date-field:change
- RULE: Time entry is a TimeField (poetry_time_field / form.time_field) - never a masked Input or a pair of selects; params[<name>] is HH:MM (HH:MM:SS with seconds:).
- RULE: 12- vs 24-hour follows the user's locale automatically (the dayPeriod segment appears only under twelve-hour cycles); hour_cycle: pins it when a product must.
- RULE: For a date AND a time, compose a DateField and a TimeField side by side - there is no datetime component by design.

## toggle (`poetry_toggle`)

A two-state button that can be pressed on or off.

Class: Poetry::Ui::Toggle::Component - BEM block `poetry-ui-toggle`.
- `size:` (symbol) - one of default|sm|lg, default "default", required
- `variant:` (symbol) - one of default|outline, default "default", required
- `disabled:` (boolean) - default false
- `label:` (string)
- `pressed:` (boolean) - default false
- PART `toggle` - The pressed-state <button> - the whole component; aria-pressed carries the state and the controller flips both together | states: data-pressed (pressed (bare presence boolean - absent when unpressed, never data-pressed=false)); data-disabled (disabled (rendered alongside native disabled for styling-hook parity)); data-variant=default|outline (the visual variant); data-size=default|sm|lg (the size)
- WIRING `poetry--core--pressed`: actions press, set, toggle, unpress; events poetry:toggle:change
- RULE: Use poetry_toggle - never a Button with hand-managed aria-pressed.
- RULE: Toggle is UI state, NOT form data: never try to submit it. Form value -> Checkbox; instant setting -> Switch; exclusive/grouped -> ToggleGroup.
- RULE: Icon-only toggles MUST pass label:, and the label must NOT change with state ('Bookmark', never 'Remove bookmark').
- RULE: aria-pressed is the vocabulary - never aria-checked or aria-expanded on a Toggle.
- RULE: Wire the EFFECT to poetry:toggle:change (or click) and revert via set(false) on failure - a pressed toggle whose effect failed is a lie.
- RULE: Pressed visual is accent - don't override data-pressed colors per-instance (theme-level only).

## toggle_group (`poetry_toggle_group`)

A set of toggle buttons for single or multiple selection.

Class: Poetry::Ui::ToggleGroup::Component - BEM block `poetry-ui-toggle_group`.
Slot REQUIRED: with_item (at least one item) - a call without it raises.
- `size:` (symbol) - one of default|sm|lg, default "default", required
- `variant:` (symbol) - one of default|outline, default "default", required
- `disabled:` (boolean) - default false
- `label:` (string)
- `orientation:` (symbol) - one of horizontal|vertical, default "horizontal"
- `spacing:` (integer) - default 0
- `type:` (symbol) - default "single"
- `value:` (string)
- `values:` (list) - default "dynamic"
Slots: items (many; with_item yields NOTHING to the block - no |param|, write content directly).
- PART `toggle-group` - The role=radiogroup (single) / role=toolbar (multiple) root - the value-set machine and roving focus ride here; the axes cascade to items | states: data-variant=default|outline (the shared Toggle variant (root wins)); data-size=default|sm|lg (the shared Toggle size (root wins)); data-spacing (the gap step - 0 is the segmented chain (joined corners), >0 free-standing); data-orientation=horizontal|vertical (the roving axis); data-disabled (the whole group is disabled (disables every item)) | vars: --gap (the item gap, set inline from spacing: - the root's gap utility consumes it)
- PART `toggle-group-item` - One dumb <button> under the group machine - Toggle-styled, no per-item controller | states: data-pressed (pressed (bare presence boolean - absent when off; the controller rederives the type-correct aria attribute from it)); data-disabled (the item (or the whole group) is disabled - the roving-focus collection filter); data-value (the item's key in the value set (always present, unique)); data-variant=default|outline (cascaded from the root); data-size=default|sm|lg (cascaded from the root); data-spacing (cascaded from the root - keys the segmented corner/border chain)
- WIRING `poetry--core--roving-focus`: values loop, manageTabindex, orientation; actions keydown; events poetry--core--roving-focus:entry
- WIRING `poetry--core--toggle-group`: values type; actions setValue, toggle; events poetry:toggle-group:change
- RULE: Use poetry_toggle_group - never hand-assemble Toggles with your own exclusivity logic.
- RULE: ToggleGroup is UI state, NOT form data: submitting single-select -> RadioGroup; submitting multi-select -> Checkbox group. No name: exists; don't route around it.
- RULE: Every item MUST have a unique value: (ArgumentError on duplicates); icon-only items MUST pass label: (state-invariant).
- RULE: Name the group via label: - a nameless radiogroup/toolbar fails the audit.
- RULE: Exclusive view/mode switching that shows PANELS is Tabs (aria-selected + tabpanels), not a single ToggleGroup.
- RULE: Never mix vocabularies: single items carry aria-checked, multiple carry aria-pressed - the controller enforces it; agents patching DOM must too.
- RULE: single deselects to empty by re-press (Radix-exact) - if your UI needs always-one-selected, handle the empty change in the host.

