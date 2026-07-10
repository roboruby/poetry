# poetry chat components

Contracts generated from the registry. `RULE` lines are constraints,
not suggestions. Options are keywords; content is the block.

## attachment (`poetry_attachment`)

Class: Poetry::Ui::Attachment::Component - BEM block `poetry-ui-attachment`.
- `orientation:` (symbol) - one of horizontal|vertical, default "horizontal", required
- `size:` (symbol) - one of default|sm|xs, default "default", required
- `state:` (symbol) - one of idle|uploading|processing|error|done, default "done"
Slots: media (with_media yields NOTHING to the block - no |param|, write content directly; with_media keywords: variant: ONLY), title, description, actions (many; with_action yields NOTHING to the block - no |param|, write content directly), trigger (with_trigger yields NOTHING to the block - no |param|, write content directly).
- RULE: State is server-owned: render data-upload-state and flip it by Turbo Stream replace - never toggle it in JS.
- RULE: with_media(variant: :image) wraps the caller's <img>; file names and URLs are user content - never render them html_safe.
- RULE: Actions are with_action(...) poetry Buttons (ghost/icon-xs defaults) - each needs label: (icon-only).
- RULE: with_trigger makes the whole chip the control (a stretched overlay UNDER the actions) - don't also wrap the chip in a link.
- RULE: error state needs a with_description explaining the failure - the tint alone is not the message.

## bubble (`poetry_bubble`)

Class: Poetry::Ui::Bubble::Component - BEM block `poetry-ui-bubble`.
- `variant:` (symbol) - one of default|secondary|muted|tinted|outline|ghost|destructive, default "default", required
- `align:` (symbol) - one of start|end, default "start"
- `href:` (string)
- `tag:` (symbol) - one of div|button|a, default "div"
Slots: reactions (with_reactions yields NOTHING to the block - no |param|, write content directly; with_reactions keywords: label:, side:, align: ONLY).
- RULE: One Bubble per message; stack a sender's run inside poetry_bubble_group.
- RULE: Quick replies are tag: :button (with the caller's data-action) or tag: :a + href: - never a click handler on a div.
- RULE: ghost is for tool output / system text flowing full-width - not a visual preference.
- RULE: Reactions REQUIRE label: (the accessible name for the cluster).
- RULE: Inside a Message, alignment follows the Message's align - do not set both.

## message (`poetry_message`)

Class: Poetry::Ui::Message::Component - BEM block `poetry-ui-message`.
- `align:` (symbol) - one of start|end, default "start"
Slots: avatar, header, footer.
- RULE: One Message per turn: avatar slot + header/footer slots; the body block holds the Bubbles.
- RULE: align: :end is the local user's side - set it on the Message, never on the Bubbles inside.
- RULE: The avatar slot is decorative context by default - pass meaningful sender identity in the header.
- RULE: Timestamps and delivery state belong in the footer slot (it lifts the avatar automatically).

## message_scroller (`poetry_message_scroller`)

Class: Poetry::Ui::MessageScroller::Component - BEM block `poetry-ui-message_scroller`.
- `auto_scroll:` (boolean) - default true
- `default_scroll_position:` (symbol) - one of start|end|last-anchor, default "end"
- `id:` (string) - required
- `jump_button:` (boolean) - default true
- `preserve_scroll_on_prepend:` (boolean) - default true
- `track_visibility:` (boolean) - default false
- WIRING `poetry--core--message-scroller`: targets button, content, spacer, viewport; values autoScroll, defaultScrollPosition, preserveScrollOnPrepend, scrollEdgeThreshold, scrollMargin, scrollPreviousItemPeek, trackVisibility; actions autoScrollValueChanged, defaultScrollPositionValueChanged, jump, keydownIntent, scrollToEnd, scrollToMessage, scrollToStart, syncAfterScroll, userScrollIntent; events poetry--core--message-scroller:mode, poetry--core--message-scroller:pinned, poetry--core--message-scroller:scrollable, poetry--core--message-scroller:unpinned, poetry--core--message-scroller:visibility
- RULE: Stream by UPDATING a row's text (morph/replace) - appending nodes per token re-announces the row to AT.
- RULE: Rows are poetry_message_scroller_item(id: message.id) - the id is how anchoring and Streams find them.
- RULE: Append new turns with a Turbo Stream targeting the content element's dom id.
- RULE: History loads PREPEND into the content element - the controller preserves the reading position.
- RULE: Never nest a second scroll container inside the viewport.

