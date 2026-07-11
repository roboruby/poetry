# poetry layout components

Contracts generated from the registry. `RULE` lines are constraints,
not suggestions. Options are keywords; content is the block.

## aspect_ratio (`poetry_aspect_ratio`)

Class: Poetry::Ui::AspectRatio::Component - BEM block `poetry-ui-aspect_ratio`.
- `ratio:` (string) - required
- RULE: Pass ratio: as a string fraction ('16/9', '1/1') - Ruby's 16/9 is integer division (1).
- RULE: The child fills the box itself (size-full object-cover on an image).

## resizable (`poetry_resizable`)

Class: Poetry::Ui::Resizable::Component - BEM block `poetry-ui-resizable`.
Slot REQUIRED: with_panel (at least two panels) - a call without it raises.
- `direction:` (symbol) - one of horizontal|vertical, default "horizontal"
- `grip:` (boolean) - default false
Slots: panels (many; with_panel yields NOTHING to the block - no |param|, write content directly; with_panel keywords: default_size:, min_size:, max_size:, classes: ONLY; with_panel REQUIRES a content block (the panel content)).
- WIRING `poetry--core--resizable`: values orientation; actions dragEnd, dragMove, dragStart, keydown; events poetry--core--resizable:resize
- RULE: Declare panels with with_panel(default_size:, min_size:, max_size:) - sizes are PERCENTAGES and the component interleaves the separator handles.
- RULE: direction: :horizontal is side-by-side (the default); :vertical stacks.
- RULE: Handles are keyboard splitters (arrows step, Home/End jump) - never replace them with styled divs.
- RULE: Nest a group inside a panel for two-axis layouts - groups self-scope.

## scroll_area (`poetry_scroll_area`)

Class: Poetry::Ui::ScrollArea::Component - BEM block `poetry-ui-scroll_area`.
Content block REQUIRED (what scrolls) - a blockless call raises.
- `label:` (string) - required
- RULE: Size the scroll area with classes (h-72 w-48, max-h-96) - content decides the overflow.
- RULE: label: is REQUIRED - the viewport is focusable, and a focusable region needs a name (role=region + aria-label).
- RULE: This is a NATIVE scroll surface - never bolt scroll JS onto it; use MessageScroller for chat transcripts.

