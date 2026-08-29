# Changelog

## [Unreleased]

### Changed

- Upstream pin moved to the `shadcn@4.19.0` release (`1773ecfe`); pins are tagged releases from here on. Adopted: the choice-card focus treatment on checkbox, radio, switch and field labels in every ported theme; the questionnaire rules re-transcribed at the new pin (its invalid state reads from the item). Recorded: the React Aria base's selectors as not ported. Deferred: toast alignment, until upstream ships per-style toast rules.
- CommandDialog: the classic h-12 input row / `py-3` rows / 20px icons sizing now lives in the default theme's `.cn-command-dialog` rule; the eight ported themes render the dialog palette with their own well and row sizes, as their source does.
- CommandDialog: the close X now seats inside the input row as its trailing item (centred in every theme, never over the input) and is off by default — the palette is keyboard-first (Esc, the backdrop, or picking an item closes it) — appearing automatically with `dismissible: false`; `show_close_button: true` forces it.

### Fixed

- Questionnaire: the checkbox check glyph sat in the corner of its box (an unsized icon inside a wrapper span fell back to its 24px intrinsic size); the icon now carries the indicator-check part itself, sized by every theme. A `checked_choices` preview holds the checked geometry in the goldens, and the visual walk fails on any icon larger than its box.
- CommandDialog: the panel carries the source's structural `overflow-hidden p-0`, so vega/nova/lyra no longer render the palette inside the dialog's own padding.
- Combobox: the popup's list now carries the option inset (`cn-combobox-list`, with the group label on `cn-combobox-label` and groups unpadded), so ungrouped options no longer sit flush against the search field, and the popup's column layout lets long lists scroll to their last option under every theme's cap.
- Command: the eight ported themes styled the highlighted row on `data-selected` (the committed value) instead of `data-highlighted`, leaving keyboard and pointer highlight invisible in palettes and the command dialog; the item and shortcut rules now key on the highlight.
- Command: a list holding loose items (outside any group) now carries the option inset itself and its groups drop their horizontal padding, so the first row clears the search field and loose and grouped rows align (lyra stays flush by design).
