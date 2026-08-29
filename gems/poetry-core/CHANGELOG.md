# Changelog

## [Unreleased]

### Fixed

- `html_attributes` sets the resolved class instead of merging it over the caller's original, so a caller's non-utility class token (a `cn-*` hook) no longer renders twice.

### Changed

- Part contract: an embedded component's root that wears a part the outer component declares (an icon rendered as an indicator glyph) counts as the outer component's part instead of reporting it as unrendered.
