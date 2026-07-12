# poetry forms components

Contracts generated from the registry. `RULE` lines are constraints,
not suggestions. Options are keywords; content is the block.

## button (`poetry_button`)

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
In blocks: `app-shell`, `data-index`, `destructive-panel`, `page-header`, `top-nav` - for a screen, start from the block (MCP compose/describe_block, or `bin/rails g poetry:block`), not from scratch.
- RULE: Use poetry_button - never a raw <button> with hand-written Tailwind.
- RULE: The visible text is the content block: poetry_button { "Save" }. label: is ONLY the accessible name.
- RULE: Icon-only buttons (size: :icon*) MUST pass label: (the accessible name).
- RULE: Link-styled actions use variant: :link - not <a> with button classes.
- RULE: Loading via loading: - never a manual disabled + spinner.
- RULE: Never nest an interactive element inside a Button.
- RULE: Pick the variant by intent; one primary (default) action per view.

## button_group (`poetry_button_group`)

Class: Poetry::Ui::ButtonGroup::Component - BEM block `poetry-ui-button_group`.
Content block REQUIRED (its member controls) - a blockless call raises.
- `orientation:` (symbol) - one of horizontal|vertical, default "horizontal", required
In blocks: `data-index` - for a screen, start from the block (MCP compose/describe_block, or `bin/rails g poetry:block`), not from scratch.
- RULE: Members go in the content block - the group's selectors join ANY data-slot children (buttons, inputs, select triggers); never hand-round the inner corners.
- RULE: Give the group an aria-label when the page has more than one (role=group is unnamed by default).
- RULE: A visual divider between members is poetry_button_group_separator, not a styled border.

## calendar (`poetry_calendar`)

Class: Poetry::Ui::Calendar::Component - BEM block `poetry-ui-calendar`.
- `mode:` (symbol) - default "single"
- `name:` (string)
- `week_start:` (integer) - default 0
- WIRING `poetry--core--calendar`: targets caption, day, endInput, grid, input, startInput; values max, min, mode, month, monthNames, rangeEnd, rangeStart, selected, weekStart; actions keydown, nextMonth, previousMonth, select; events poetry--core--calendar:change
- RULE: name: makes it a form control (the chosen date posts as an ISO string in a hidden input; range mode posts name[start] + name[end]).
- RULE: month:/selected:/today accept a Date or an ISO string; min:/max: bound the selectable range.
- RULE: mode: :range selects a span - selected: takes a Date..Date Range, [start, end], or {start:, end:}; the second click completes, click-before-start swaps, re-click clears.
- RULE: The grid is server-rendered - it shows a valid month with no JS; the controller adds navigation + selection.
- RULE: For a text-field + popover, use DatePicker (it composes this) - a bare Calendar is the always-visible grid.

## checkbox (`poetry_checkbox`)

Class: Poetry::Ui::Checkbox::Component - BEM block `poetry-ui-checkbox`.
- `checked:` (checked_state) - default false
- `disabled:` (boolean) - default false
- `label:` (string)
- `name:` (string)
- `required:` (boolean) - default false
- `unchecked_value:` (string) - default "0"
- `value:` (string) - default "1"
- WIRING `poetry--core--checked`: values inputId; actions check, set, toggle, uncheck; events poetry--core--checked:change
- RULE: Use poetry_checkbox (or f.check_box) - never a raw input[type=checkbox] with hand-written Tailwind, and never a hand-rolled button[role=checkbox].
- RULE: Always give it a name: in forms - a checkbox without one submits nothing (visual-only mode is for controlled UI like DataTable row selection ONLY).
- RULE: Every checkbox needs an accessible name: a Label/Field for= association (preferred) or label:.
- RULE: Indeterminate is set programmatically/server-side only - no user gesture produces it; use it for select-all parents.
- RULE: Instant-effect settings use Switch; pressed UI tools use Toggle; one-of-N uses RadioGroup.
- RULE: NEVER write the checked attributes (data-checked/data-unchecked/data-indeterminate) without aria-checked and the input's checked property (the controller writes all three; agents patching DOM must too).
- RULE: Don't suppress unchecked_value unless using the array idiom - an unchecked box that submits nothing silently keeps the old server value.

## combobox (`poetry_combobox`)

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
- WIRING `poetry--core--combobox`: values modal, open, value; actions close, nativeChanged, open, openValueChanged, setValue, toggle, triggerKeydown, valueValueChanged; events poetry:combobox:change, poetry:combobox:closed, poetry:combobox:open, poetry:combobox:select
- WIRING `poetry--core--command`: values debounce, filter, loop; actions activate, filterInput, highlightItem, keydown, pointerHighlight, reset; events poetry:command:filter, poetry:command:highlight, poetry:command:select
- WIRING `poetry--core--popper`: targets anchor, arrow, content; values align, alignOffset, anchor, anchorPoint, avoidCollisions, side, sideOffset, strategy; actions anchorPointValueChanged, reposition, setAnchor, setAnchorElement
- RULE: Use poetry_combobox (f.poetry_combobox in forms) - never hand-wire Popover+Command+hidden-input; this component IS that wiring, with the form story done right.
- RULE: Combobox picks VALUES. Filter-then-ACT is bare Command; short known lists are Select; free text is Input.
- RULE: Every Combobox MUST be named (Field label via id: or aria-label) - a nameless bare combobox fails at render.
- RULE: NEVER write aria-selected from highlight logic (position is data-highlighted + aria-activedescendant); NEVER write the display without the native select first - the commit pipeline does all of it; agents patching DOM must too.
- RULE: Async options: filter: false + the Turbo-frame ?q= recipe - AND the frame must render the twin native <option> for every committable item (the recipe's one hard rule).
- RULE: In forms, always f.poetry_combobox; multiple: raises - multi-select/chips is not shipped (do not fake it with hidden inputs).
- RULE: Do not put interactive elements inside options (an option IS the interactive unit).
- RULE: Deselection is include_blank (a visible blank option), never a re-click toggle - committing the already-selected value closes without change.

## date_picker (`poetry_date_picker`)

Class: Poetry::Ui::DatePicker::Component - BEM block `poetry-ui-date_picker`.
- `label:` (string)
- `mode:` (symbol) - default "single"
- `name:` (string) - required
- `placeholder:` (string) - default "Pick a date"
- WIRING `poetry--core--date-picker`: targets label; values locale, mode, placeholder; actions picked
- RULE: name: is REQUIRED - the chosen date posts as an ISO string (the Calendar's hidden input).
- RULE: value: preselects a date (a Date or ISO string) - the trigger shows it formatted, no JS needed.
- RULE: min:/max: bound the selectable range; the label + placeholder are the trigger's text.
- RULE: For an always-visible grid use Calendar directly - DatePicker is the field+popover form.

## field (`poetry_field`)

Class: Poetry::Ui::Field::Component - BEM block `poetry-ui-field`.
- `orientation:` (symbol) - one of vertical|horizontal, default "vertical", required
- `error:` (string)
- `group:` (boolean) - default false
- `hint:` (string)
- `id:` (string) - required
- `label_text:` (string)
- `required:` (boolean) - default false
- RULE: Wire the control with field.control_attributes - never hand-write aria-describedby.
- RULE: Error text arrives via error: (from model errors upstream) - never a bare red <p>.
- RULE: orientation: :horizontal is the boolean-control layout (checkbox/switch left, label + hint stacked right) - text inputs and groups stay vertical.

## input (`poetry_input`)

Class: Poetry::Ui::Input::Component - BEM block `poetry-ui-input`.
- `disabled:` (boolean) - default false
- `invalid:` (boolean) - default false
- `name:` (string)
- `placeholder:` (string)
- `type:` (string) - default "text"
- `value:` (string)
- RULE: Inside a form, never render Input directly - use the FormBuilder's field (it wires ids, errors, and aria).
- RULE: Error styling comes from aria-invalid, set from model errors - never hand-toggle error classes.

## input_group (`poetry_input_group`)

Class: Poetry::Ui::InputGroup::Component - BEM block `poetry-ui-input_group`.
Content block REQUIRED (its control + addons) - a blockless call raises.
In blocks: `data-index` - for a screen, start from the block (MCP compose/describe_block, or `bin/rails g poetry:block`), not from scratch.
- RULE: The control INSIDE must be poetry_input_group_input/_textarea - a plain poetry_input keeps its own border+ring and double-chromes the group.
- RULE: Addons are poetry_input_group_addon(align:) wrapping icons/text/buttons; use poetry_input_group_text for muted captions and poetry_input_group_button for tiny actions.
- RULE: The group is a surface, not a label - the control still needs its Label/Field pairing.

## input_otp (`poetry_input_otp`)

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
- WIRING `poetry--core--otp`: targets input, slot; values length, pattern; actions focusInput, paste, sync; events poetry:otp:change, poetry:otp:complete
- RULE: Use poetry_input_otp / form.otp_field - NEVER build per-cell inputs (n Tab stops, broken paste, broken SMS autofill, unnameable cells).
- RULE: Label via Field always ('Verification code'); put the length in the hint.
- RULE: groups must sum to length (ArgumentError).
- RULE: Do NOT auto-submit on poetry:otp:complete without a visible confirm affordance - silent submit on the 6th keystroke strands users who mistyped char 3.
- RULE: Never pre-fill value: with a real code in previews/test fixtures beyond dummies; never log the value (it is a live credential).
- RULE: InputOTP is for CODES - passwords use Input type=password, longer identifiers use Input.

## label (`poetry_label`)

Class: Poetry::Ui::Label::Component - BEM block `poetry-ui-label`.
- `for_id:` (string)
In blocks: `data-index` - for a screen, start from the block (MCP compose/describe_block, or `bin/rails g poetry:block`), not from scratch.
- RULE: Every control gets a Label wired via for_id - placeholder text is never the label.

## native_select (`poetry_native_select`)

Class: Poetry::Ui::NativeSelect::Component - BEM block `poetry-ui-native_select`.
- `disabled:` (boolean) - default false
- `id:` (string)
- `invalid:` (boolean) - default false
- `label:` (string)
- `name:` (string)
- `size:` (symbol) - one of default|sm, default "default"
In blocks: `data-index` - for a screen, start from the block (MCP compose/describe_block, or `bin/rails g poetry:block`), not from scratch.
- RULE: This is a REAL <select> - use it for plain picking; the JS Select is for styled options.
- RULE: Pair it with a Label (for_id: its id) or a Field - a bare select has no accessible name.
- RULE: The fast path is options: [[label, value], ...] + selected:; a content block overrides it.

## radio_group (`poetry_radio_group`)

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

## select (`poetry_select`)

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

## slider (`poetry_slider`)

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
- WIRING `poetry--core--slider`: targets input, range, thumb, track; values inverted, max, min, minStepsBetweenThumbs, orientation, step, value; actions keydown, pointerdown, setValue, valueValueChanged; events poetry:slider:change, poetry:slider:commit
- RULE: Use poetry_slider / form.slider - never hand-roll a draggable div.
- RULE: Every thumb MUST have a distinct accessible name (label: - array of two for ranges). ArgumentError otherwise.
- RULE: Give value_text: whenever the number alone is meaningless ('$200', '80%') - SR users hear aria-valuetext.
- RULE: Range mode: values must be sorted [low, high]; use min_steps_between_thumbs to keep a meaningful gap.
- RULE: Do not use Slider for precise known-number entry (use Input type=number) or in no-JS-required forms (native input type=range).
- RULE: Debounce on poetry:slider:commit, never on :change (change fires every drag frame).
- RULE: Never transition the thumb/range position with CSS - geometry must track the pointer.

## switch (`poetry_switch`)

Class: Poetry::Ui::Switch::Component - BEM block `poetry-ui-switch`.
- `size:` (symbol) - one of default|sm, default "default", required
- `checked:` (boolean) - default false
- `disabled:` (boolean) - default false
- `label:` (string)
- `name:` (string)
- `required:` (boolean) - default false
- `unchecked_value:` (string) - default "0"
- `value:` (string) - default "1"
- WIRING `poetry--core--checked`: values inputId; actions check, set, toggle, uncheck; events poetry--core--checked:change
- RULE: Use poetry_switch - never a styled checkbox pretending to be a switch (role=switch announces on/off; that's the point).
- RULE: Switch = instant effect; Checkbox = staged for submit. If nothing happens until a Save button, use Checkbox.
- RULE: Every switch needs an accessible name (Label/Field for= or label:).
- RULE: Switches are BINARY - no indeterminate, ever (ArgumentError). A third state means a different component.
- RULE: The instant-effect recipe pairs the flip with server persistence (Turbo auto-submit) - never flip UI-only for a setting the user believes is saved.
- RULE: NEVER write the checked attributes (data-checked/data-unchecked) without aria-checked and the input sync (the controller writes all three).

## textarea (`poetry_textarea`)

Class: Poetry::Ui::Textarea::Component - BEM block `poetry-ui-textarea`.
- `disabled:` (boolean) - default false
- `invalid:` (boolean) - default false
- `name:` (string)
- `placeholder:` (string)
- `rows:` (integer)
- `value:` (string)
- RULE: Wire through Field/FormBuilder (control_attributes) - never hand-write the aria plumbing.
- RULE: Placeholder is NOT a label - pair with Label/Field always.
- RULE: Use Textarea for free text; Input for single-line; do not bolt a JS autosizer on (auto-grow is CSS).
- RULE: Do not set native required - required flows as aria-required via Field.

## toggle (`poetry_toggle`)

Class: Poetry::Ui::Toggle::Component - BEM block `poetry-ui-toggle`.
- `size:` (symbol) - one of default|sm|lg, default "default", required
- `variant:` (symbol) - one of default|outline, default "default", required
- `disabled:` (boolean) - default false
- `label:` (string)
- `pressed:` (boolean) - default false
- WIRING `poetry--core--pressed`: actions press, set, toggle, unpress; events poetry:toggle:change
- RULE: Use poetry_toggle - never a Button with hand-managed aria-pressed.
- RULE: Toggle is UI state, NOT form data: never try to submit it. Form value -> Checkbox; instant setting -> Switch; exclusive/grouped -> ToggleGroup.
- RULE: Icon-only toggles MUST pass label:, and the label must NOT change with state ('Bookmark', never 'Remove bookmark').
- RULE: aria-pressed is the vocabulary - never aria-checked or aria-expanded on a Toggle.
- RULE: Wire the EFFECT to poetry:toggle:change (or click) and revert via set(false) on failure - a pressed toggle whose effect failed is a lie.
- RULE: Pressed visual is accent - don't override data-pressed colors per-instance (theme-level only).

## toggle_group (`poetry_toggle_group`)

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
- WIRING `poetry--core--roving-focus`: values loop, manageTabindex, orientation; actions keydown; events poetry--core--roving-focus:entry
- WIRING `poetry--core--toggle-group`: values type; actions setValue, toggle; events poetry:toggle-group:change
- RULE: Use poetry_toggle_group - never hand-assemble Toggles with your own exclusivity logic.
- RULE: ToggleGroup is UI state, NOT form data: submitting single-select -> RadioGroup; submitting multi-select -> Checkbox group. No name: exists; don't route around it.
- RULE: Every item MUST have a unique value: (ArgumentError on duplicates); icon-only items MUST pass label: (state-invariant).
- RULE: Name the group via label: - a nameless radiogroup/toolbar fails the audit.
- RULE: Exclusive view/mode switching that shows PANELS is Tabs (aria-selected + tabpanels), not a single ToggleGroup.
- RULE: Never mix vocabularies: single items carry aria-checked, multiple carry aria-pressed - the controller enforces it; agents patching DOM must too.
- RULE: single deselects to empty by re-press (Radix-exact) - if your UI needs always-one-selected, handle the empty change in the host.

