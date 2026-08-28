# Changelog

## [Unreleased]

### Fixed

- Combobox: the popup's list now carries the option inset (`cn-combobox-list`, with the group label on `cn-combobox-label` and groups unpadded), so ungrouped options no longer sit flush against the search field, and the popup's column layout lets long lists scroll to their last option under every theme's cap.
- Command: the eight ported themes styled the highlighted row on `data-selected` (the committed value) instead of `data-highlighted`, leaving keyboard and pointer highlight invisible in palettes and the command dialog; the item and shortcut rules now key on the highlight.
- Command: a list holding loose items (outside any group) now carries the option inset itself and its groups drop their horizontal padding, so the first row clears the search field and loose and grouped rows align (lyra stays flush by design).
