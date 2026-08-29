# Changelog

## [Unreleased]

### Added

- Dictionary fidelity ledger: every Style dictionary's structural tokens are held against the styled source's classNames per `data-slot` at the pin (`config/dictionary_fidelity/`, `rake css:dictionary_snapshot`, `rake css:verify_dictionary_fidelity`, the gate in the default chain). Exact and two-way like the theme ledger; 46 components carry receipts for their deliberate differences.

### Changed

- Part names align with the source's vocabulary (host CSS keyed on the old names must follow): the combobox's embedded parts are `combobox-list`, `combobox-item`, `combobox-group`, `combobox-label`, `combobox-empty`, `combobox-separator`, `combobox-chip-input`, `combobox-input`, `combobox-input-wrapper`, `combobox-search-icon`, `combobox-item-text`, `combobox-loading`, `combobox-status` and `combobox-command` (were `command-*`); menu indicators are `<menu>-checkbox-item-indicator` / `<menu>-radio-item-indicator` (was one `<menu>-item-indicator`); the field's hint is `field-description` and its Label wears `field-label`. The command engine resolves both vocabularies.
- Dictionaries adopt the styled source's structural tokens (group markers, the bare `data-disabled:` spelling, the combobox popup's width policy, the dropdown content's anchor width, tabs trigger states, badge rings, card header/footer chains, and more); the card footer's border padding and the select item's trailing-span layout move into the default theme rule.
- New parts: `accordion-trigger-icon`, `dialog-close`; `native-select-icon` is the svg itself; a `with_media` alert-dialog preview.
- Upstream pin moved to the `shadcn@4.19.0` release (`1773ecfe`); pins are tagged releases from here on. Adopted: the choice-card focus treatment on checkbox, radio, switch and field labels in every ported theme; the questionnaire rules re-transcribed at the new pin (its invalid state reads from the item). Recorded: the React Aria base's selectors as not ported. Deferred: toast alignment, until upstream ships per-style toast rules.
- CommandDialog: the classic h-12 input row / `py-3` rows / 20px icons sizing now lives in the default theme's `.cn-command-dialog` rule; the eight ported themes render the dialog palette with their own well and row sizes, as their source does.
- CommandDialog: the close X now seats inside the input row as its trailing item (centred in every theme, never over the input) and is off by default — the palette is keyboard-first (Esc, the backdrop, or picking an item closes it) — appearing automatically with `dismissible: false`; `show_close_button: true` forces it.

### Fixed

- Questionnaire (mira, lyra): the choice indicator sat 1.5px below the text line - the source's optical nudge is tuned for the default style's 14px text, and these themes set the choice to text-xs. Dropped there and recorded in the fidelity ledger.
- Questionnaire: the checkbox check glyph sat in the corner of its box (an unsized icon inside a wrapper span fell back to its 24px intrinsic size); the icon now carries the indicator-check part itself, sized by every theme. A `checked_choices` preview holds the checked geometry in the goldens, and the visual walk fails on any icon larger than its box.
- CommandDialog: the panel carries the source's structural `overflow-hidden p-0`, so vega/nova/lyra no longer render the palette inside the dialog's own padding.
- Combobox: the popup's list now carries the option inset (`cn-combobox-list`, with the group label on `cn-combobox-label` and groups unpadded), so ungrouped options no longer sit flush against the search field, and the popup's column layout lets long lists scroll to their last option under every theme's cap.
- Command: the eight ported themes styled the highlighted row on `data-selected` (the committed value) instead of `data-highlighted`, leaving keyboard and pointer highlight invisible in palettes and the command dialog; the item and shortcut rules now key on the highlight.
- Command: a list holding loose items (outside any group) now carries the option inset itself and its groups drop their horizontal padding, so the first row clears the search field and loose and grouped rows align (lyra stays flush by design).
