# poetry chat components

Contracts generated from the registry. `RULE` lines are constraints,
not suggestions. Options are keywords; content is the block.

## attachment (`poetry_attachment`)

Class: Poetry::Ui::Attachment::Component - BEM block `poetry-ui-attachment`.
- `orientation:` (symbol) - one of horizontal|vertical, default "horizontal", required
- `size:` (symbol) - one of default|sm|xs, default "default", required
- `state:` (symbol) - one of idle|uploading|processing|error|done, default "done"
Slots: media (with_media yields NOTHING to the block - no |param|, write content directly; with_media keywords: variant: ONLY), title, description, actions (many; with_action yields NOTHING to the block - no |param|, write content directly), trigger (with_trigger yields NOTHING to the block - no |param|, write content directly).
- PART `attachment` - The chip root - the server-owned upload lifecycle rides here (flip data-upload-state by re-render / Turbo Stream replace) | states: data-upload-state=idle|uploading|processing|error|done (always - the resolved state); data-size=default|sm|xs (always - the resolved size); data-orientation=horizontal|vertical (always - the resolved orientation)
- PART `attachment-media` - The media slot's box - the icon tile or the caller's <img> | states: data-variant=icon|image (always - the media variant)
- PART `attachment-content` - Text column wrapping title/description - renders when either slot is set
- PART `attachment-title` - The file name line (title slot; user content, never html_safe)
- PART `attachment-description` - Muted metadata / failure copy under the title
- PART `attachment-actions` - Row of with_action poetry Buttons
- PART `attachment-status` - sr-only role=status announcement for the in-flight and error states (uploading/processing/error)
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
- PART `bubble` - The message surface root - variant and alignment ride here | states: data-variant=default|secondary|muted|tinted|outline|ghost|destructive (always - the resolved variant); data-align=start|end (always - the resolved align)
- PART `bubble-content` - The body (<div>, or a <button>/<a> quick reply via tag:) - the content block renders here
- PART `bubble-reactions` - The reactions pill overlay (role=group, named by label:) | states: data-side (always - which edge the pill overlays (default bottom)); data-align (always - placement along that edge (default end))
- RULE: One Bubble per message; stack a sender's run inside poetry_bubble_group.
- RULE: Quick replies are tag: :button (with the caller's data-action) or tag: :a + href: - never a click handler on a div.
- RULE: ghost is for tool output / system text flowing full-width - not a visual preference.
- RULE: Reactions REQUIRE label: (the accessible name for the cluster).
- RULE: Inside a Message, alignment follows the Message's align - do not set both.

## message (`poetry_message`)

Class: Poetry::Ui::Message::Component - BEM block `poetry-ui-message`.
- `align:` (symbol) - one of start|end, default "start"
Slots: avatar, header, footer.
- PART `message` - The chat-row root - avatar plus a content column; align: :end mirrors the row for the local user's side | states: data-align=start|end (always - the resolved align)
- PART `message-avatar` - The avatar slot's box, kept out of the content column
- PART `message-content` - The content column - header, the body block (the Bubbles), footer
- PART `message-header` - Sender identity line above the bubbles (header slot)
- PART `message-footer` - Timestamps / delivery state below the bubbles (footer slot - it lifts the avatar)
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
- PART `message-scroller` - The transcript root the controller drives - runtime scroll state is mirrored here | states: data-mode=following-bottom|free-scrolling|anchored-to-message|settling-jump (always once connected - the 4-state machine); data-scrollable (overflow exists - carries which edges have room (start, end, or both as a space-separated pair)); data-autoscrolling (a programmatic scroll is settling - the follow-bottom release is suppressed while set)
- PART `message-scroller-viewport` - The native scroll region (role=region, focusable) - the controller mirrors the same runtime attributes here | states: data-scrollable (overflow exists - the same edge tokens as the root); data-autoscrolling (a programmatic scroll is settling)
- PART `message-scroller-content` - The row container and Turbo Stream append target (stable dom id <id>-messages); role=log announces additions
- PART `message-scroller-item` - One transcript row (poetry_message_scroller_item) - the id is how anchoring and Streams find it | states: data-message-id (always - the row's message id); data-scroll-anchor (anchor: true - the turn the controller holds at the reading line)
- PART `message-scroller-spacer` - Tail spacer faking scroll room below a short anchored turn - hidden at height 0
- WIRING `poetry--core--message-scroller`: targets button, content, spacer, viewport; values autoScroll, defaultScrollPosition, preserveScrollOnPrepend, scrollEdgeThreshold, scrollMargin, scrollPreviousItemPeek, trackVisibility; actions autoScrollValueChanged, defaultScrollPositionValueChanged, jump, keydownIntent, scrollToEnd, scrollToMessage, scrollToStart, syncAfterScroll, userScrollIntent; events poetry--core--message-scroller:mode, poetry--core--message-scroller:pinned, poetry--core--message-scroller:scrollable, poetry--core--message-scroller:unpinned, poetry--core--message-scroller:visibility
- RULE: Stream by UPDATING a row's text (morph/replace) - appending nodes per token re-announces the row to AT.
- RULE: Rows are poetry_message_scroller_item(id: message.id) - the id is how anchoring and Streams find them.
- RULE: Append new turns with a Turbo Stream targeting the content element's dom id.
- RULE: History loads PREPEND into the content element - the controller preserves the reading position.
- RULE: Never nest a second scroll container inside the viewport.

