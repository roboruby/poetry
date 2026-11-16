# poetry chat components

Contracts generated from the registry. `RULE` lines are constraints,
not suggestions. Options are keywords; content is the block.

## attachment (`poetry_attachment`)

A file or image chip showing its name, type, and size.

Class: Poetry::Ui::Attachment::Component - BEM block `poetry-ui-attachment`.
- `orientation:` (symbol) - one of horizontal|vertical, default "horizontal", required - Row (:horizontal) or stacked thumbnail-card (:vertical) layout.
- `size:` (symbol) - one of default|sm|xs, default "default", required - The chip density axis.
- `state:` (symbol) - one of idle|uploading|processing|error|done, default "done" - The upload lifecycle state; flip it by re-render or Turbo Stream replace, never in JS.
Slots: media (Leading visual: :icon (default) boxes an icon tile, :image wraps the caller's <img>.; with_media yields NOTHING to the block - no |param|, write content directly; with_media keywords: variant: ONLY), title (The file name line. User content - never mark it html_safe.), description (Muted metadata under the title (size, type); in the error state, the failure explanation.), progress (An upload's progress under the title: the Progress component, slim, its caption for screen readers only. The uploader moves it; render it with the value you know.), actions (Trailing icon actions - each renders a Button (ghost, icon-xs defaults) and requires label:.; many; with_action yields NOTHING to the block - no |param|, write content directly), trigger (Makes the whole chip the control - a stretched button (or anchor via tag: :a, href:) layered under the actions. Don't also wrap the chip in a link.; with_trigger yields NOTHING to the block - no |param|, write content directly).
- PART `attachment` - The chip root - the server-owned upload lifecycle rides here (flip data-upload-state by re-render / Turbo Stream replace) | states: data-upload-state=idle|uploading|processing|error|done (always - the resolved state); data-size=default|sm|xs (always - the resolved size); data-orientation=horizontal|vertical (always - the resolved orientation)
- PART `attachment-media` - The media slot's box - the icon tile or the caller's <img> | states: data-variant=icon|image (always - the media variant)
- PART `attachment-content` - Text column wrapping title/description - renders when either slot is set
- PART `attachment-title` - The file name line (title slot; user content, never html_safe)
- PART `attachment-description` - Muted metadata / failure copy under the title
- PART `attachment-progress` - The upload's progress bar under the title (the progress slot: a slim Progress whose caption is read, not shown)
- PART `attachment-actions` - Row of with_action poetry Buttons
- PART `attachment-trigger` - The whole-chip control (with_trigger: a button or tag: :a anchor) - wraps the picker/download affordance
- PART `attachment-status` - sr-only role=status announcement for the in-flight and error states (uploading/processing/error)
- RULE: State is server-owned: render data-upload-state and flip it by Turbo Stream replace - never toggle it in JS.
- RULE: with_media(variant: :image) wraps the caller's <img>; file names and URLs are user content - never render them html_safe.
- RULE: Actions are with_action(...) poetry Buttons (ghost/icon-xs defaults) - each needs label: (icon-only).
- RULE: with_trigger makes the whole chip the control (a stretched overlay UNDER the actions) - don't also wrap the chip in a link.
- RULE: error state needs a with_description explaining the failure - the tint alone is not the message.

## bubble (`poetry_bubble`)

A chat message bubble aligned to its sender.

Class: Poetry::Ui::Bubble::Component - BEM block `poetry-ui-bubble`.
Content block REQUIRED (the message content) - a blockless call raises.
- `variant:` (symbol) - one of default|secondary|muted|tinted|outline|ghost|destructive, default "default", required - The intent axis; :ghost is for tool output / system text flowing full-width.
- `align:` (symbol) - one of start|end, default "start" - Which side the bubble hugs; inside a Message, set the Message's align instead.
- `href:` (string) - Renders the content as a real anchor; implies tag: :a.
- `tag:` (symbol) - one of div|button|a, default "div" - The content element: :div (default), or :button/:a for a quick reply.
Slots: reactions (The reactions pill overlaid on an edge; label: names the cluster for assistive tech, side:/align: place it (default bottom end).; with_reactions yields NOTHING to the block - no |param|, write content directly; with_reactions keywords: label:, side:, align: ONLY).
- PART `bubble` - The message surface root - variant and alignment ride here | states: data-variant=default|secondary|muted|tinted|outline|ghost|destructive (always - the resolved variant); data-align=start|end (always - the resolved align)
- PART `bubble-content` - The body (<div>, or a <button>/<a> quick reply via tag:) - the content block renders here
- PART `bubble-reactions` - The reactions pill overlay (role=group, named by label:) | states: data-side (always - which edge the pill overlays (default bottom)); data-align (always - placement along that edge (default end))
In blocks: `chat` - for a screen, start from the block (MCP compose/describe_block, or `bin/rails g poetry:block`), not from scratch.
- RULE: One Bubble per message; stack a sender's run inside poetry_bubble_group.
- RULE: Quick replies are tag: :button (with the caller's data-action) or tag: :a + href: - never a click handler on a div.
- RULE: ghost is for tool output / system text flowing full-width - not a visual preference.
- RULE: Reactions REQUIRE label: (the accessible name for the cluster).
- RULE: Inside a Message, alignment follows the Message's align - do not set both.

## composer (`poetry_composer`)

A chat message form with a growing field and a Send button the server turns into Stop while a reply runs.

Class: Poetry::Ui::Composer::Component - BEM block `poetry-ui-composer`.
- `accept:` (string) - The accepted file types, in the native accept grammar ("image/*,.pdf"); other files are refused at intake with a message.
- `attach_label:` (string) - The paperclip button's accessible name. Defaults to the locale's "Attach files".
- `attachments:` (boolean) - default false - Files join the message: a paperclip button, a drop on the composer and a paste into the field, each file a chip above the field.
- `attachments_name:` (string) - default "attachments[]" - The param key the files arrive under - ending in [] for Rails params, since a message may carry several.
- `autofocus:` (boolean) - default false - Puts the caret in the field when the page opens (the native autofocus attribute) - for a page that is the conversation, one composer at most.
- `direct_upload:` (boolean) - default false - Uploads the files straight to storage through Active Storage's direct uploads, so the message posts signed ids instead of bytes.
- `direct_upload_url:` (string) - A direct uploads endpoint other than Rails' own (an authenticated or scoped route); it turns direct uploads on.
- `disabled:` (boolean) - default false - Disables the field and the Send button.
- `http_method:` (symbol) - default "post" - The form's HTTP verb. Named http_method (not method:) - an option named `method` would shadow Object#method.
- `id:` (string) - required - The composer's DOM id. The parts derive theirs from it: "<id>-form", "<id>-input", "<id>-stop", and "<id>-action" - the slot a Turbo Stream replaces.
- `input_class:` (string) - Classes merged onto the field - min-h-24 opens it taller, max-h-80 raises the ceiling it grows to before it scrolls.
- `label:` (string) - The field's accessible name (aria-label). Defaults to the locale's "Message".
- `max_files:` (integer) - The most files one message holds; the surplus is refused with a message.
- `max_size:` (integer) - The largest file a message takes, in bytes (10.megabytes).
- `name:` (string) - default "message" - The param key the message text arrives under.
- `placeholder:` (string) - Hint text shown while the field is empty - never a substitute for label:.
- `send_label:` (string) - The Send button's accessible name. Defaults to the locale's "Send message".
- `status:` (symbol) - one of idle|running|stopping, default "idle" - What the action slot shows: Send (:idle), Stop (:running), or Stop busy and disabled (:stopping). Render it from your own record of the reply.
- `stop_label:` (string) - The Stop button's accessible name. Defaults to the locale's "Stop".
- `stop_url:` (string) - Where the Stop button posts. Required for any status but :idle; the composer renders a hidden form for it beside the message form.
- `submit_on_enter:` (boolean) - default true - Enter sends and Shift+Enter breaks the line. false makes Enter a line break; Cmd/Ctrl+Enter sends either way.
- `upload:` (symbol) - one of on_submit|immediate, default "on_submit" - When direct uploads run: :on_submit as the message is sent (Rails' own flow), :immediate as each file lands, with progress, retry and remove on its chip.
- `url:` (string) - required - Where the message posts - the form's action.
- `value:` (string) - A draft to open with, rendered as the field's content.
- `version:` (integer) - A number that rises with every status change, rendered on the action slot as data-version for a versioned replace to compare. Leave it out when one ordered channel carries the status.
- PART `composer` - The root - holds the message form and the Stop form; the controller and the emptiness state ride here | states: data-empty (the field holds nothing but whitespace and no file is attached (server-set, controller-kept) - the Send button dims); data-populated (a file is attached (controller-set, with attachments:)); data-dragging (files are dragged over the composer (controller-set) - the field surface takes the drop tint); data-drag-reject (the dragged files would be refused (controller-set) - the tint turns destructive)
- PART `composer-form` - The message <form> - never replaced. Turbo marks it aria-busy while a send is in flight
- PART `composer-group` - The bordered field surface - InputGroup's chrome, focus ring keyed on the control inside
- PART `input-group-control` - The native <textarea> - InputGroup's control slot (the themes' focus-ring hook); grows with its content by CSS up to a ceiling
- PART `input-group-addon` - The footer row under the field - the tools (block content) and the action slot | states: data-align=block-end (always - the row sits under the field)
- PART `composer-action` - The slot the server redraws (dom id <id>-action) - holds Send or Stop. poetry_composer_action renders exactly this element | states: data-running (status :running or :stopping - a Stop button is in the slot); data-stopping (status :stopping - the Stop button is busy and disabled); data-version (version: was given - the number a versioned replace compares)
- PART `composer-stop-form` - The hidden <form> the Stop button submits (dom id <id>-stop) - rendered when stop_url: is given
- PART `composer-attachments` - The chips' row above the field (attachments:) - one Attachment per file, filled by the controller; hidden while empty | states: data-align=block-start (always - the row sits over the field)
- PART `composer-attachments-control` - The hidden native <input type=file> (dom id <id>-attachments) - the files' form value; the paperclip opens its picker
- PART `composer-attachment-template` - The <template> holding one Attachment chip the controller clones per file
- PART `composer-errors` - The rejections <ul> (role=alert) under the field surface - one line per refused file; hidden until a file is refused
- PART `composer-menu` - One menu's popup over the composer (with_menu) - hidden until the word at the caret starts with its trigger | states: data-open (the word at the caret starts with the trigger and an option matches it); data-closed (the menu is not showing (server default)); data-trigger (always - the character that opens the menu); data-inserts=text|chip (always - what a choice puts in the message); data-at=word|start (always - where the trigger opens the menu); data-name (name: given - the param key a chip menu's hidden fields post under); data-loading (a server-fed menu is to ask, or has asked, about the word being typed and the answer has not landed (controller-set)); data-src (src: given - the address the menu asks about the word being typed); data-param (src: given - the query key the word arrives under)
- PART `composer-menu-list` - The menu's listbox (dom id <id>-menu-<n>, named by label:) - holds options only; the field's aria-controls names it. With src: it is the <turbo-frame> the server's answers land in | states: data-query (a server-fed list holds options - the word they answer (empty for the bare trigger; controller-set after each answer))
- PART `composer-menu-option` - One option (role=option) - the field's aria-activedescendant names the highlighted one | states: data-highlighted (the option Enter, Tab or a click would choose (controller-set)); data-value (always - what the server receives for the choice); data-label (always - the option's name, and a chip's text); data-filter-value (always - what the typed word is matched against); data-keywords (always - the value and any keywords:, matched as well); data-insert (insert: given - the exact text a text menu writes); data-run (run: true - the choice is only reported)
- PART `composer-menu-option-label` - The option's name
- PART `composer-menu-option-description` - Muted text beside the name (description:)
- PART `composer-references` - The chips' row for chosen references (a chip menu) - filled by the controller, each chip holding its hidden field; hidden while empty | states: data-align=block-start (always - the row sits over the field)
- PART `composer-reference-template` - The <template> holding one reference chip the controller clones per choice
In blocks: `chat` - for a screen, start from the block (MCP compose/describe_block, or `bin/rails g poetry:block`), not from scratch.
- WIRING send: `poetry--core--composer` actions holdFocus on pointerdown; targets send
- WIRING stop: `poetry--core--composer` actions holdFocus on pointerdown, returnFocus on click; targets stop
- WIRING prompt: `poetry--core--composer-prompt` registers; values composer, text, send (if prompt_writes_only?); actions write on click
- WIRING root: `poetry--core--file-drop` (if attachments) registers; values accept, multiple, max_files, max_size, paste, messages | `poetry--core--file-input` (if attachments) registers; values multiple, upload, name, url, preview, messages; actions files on poetry:file-drop:files, discard on poetry:composer:sent | `poetry--core--composer-menu` (if menus?) registers; values messages; actions sent on poetry:composer:sent, restore on turbo:morph-element | `poetry--core--composer` registers; values submit_on_enter; actions changed on turbo:morph-element
- WIRING form: `poetry--core--composer` actions guard on submit, settle on turbo:submit-end; targets form
- WIRING input: `poetry--core--composer-menu` (if menus?) actions keydown on keydown, track on input/keyup/click/focus, blurred on blur; targets input | `poetry--core--composer` actions keydown on keydown, changed on input; targets input
- WIRING menu: `poetry--core--composer-menu` actions hold on pointerdown, pick on click, point on pointermove, loaded on turbo:frame-load, answered on turbo:before-fetch-response, failed on turbo:frame-missing/turbo:fetch-request-error; targets menu
- WIRING references: `poetry--core--composer-menu` actions keep on turbo:before-morph-element; targets chips
- WIRING reference_template: `poetry--core--composer-menu` targets template
- WIRING reference_remove: `poetry--core--composer-menu` actions remove on click
- WIRING attachments_control: `poetry--core--file-drop` targets input | `poetry--core--file-input` targets input | `poetry--core--composer` actions changed on change; targets attachments
- WIRING attach: `poetry--core--file-drop` actions open on click | `poetry--core--composer` actions holdFocus on pointerdown
- WIRING attachments: `poetry--core--file-input` actions keep on turbo:before-morph-element; targets items
- WIRING attachment_template: `poetry--core--file-input` targets template
- WIRING attachment_errors: `poetry--core--file-input` targets errors
- WIRING attachment_remove: `poetry--core--file-input` actions remove on click
- WIRING attachment_retry: `poetry--core--file-input` actions retry on click
- BEHAVIOR file_drop (on root) - Files arrive by drop, picker or paste and are checked against accept, size and count before they land in the native input.
- tool set_text (mutating; params: text (string, required)) - Write the message's text into the field, replacing the draft. It does not send. [opt in with webmcp: "name" on the call; dispatches poetry--core--composer#setText]
- tool send (mutating, consequential) - Send the message in the field, as a press of Send would. Nothing goes while the field is blank, a reply is running or a send is on its way; the answer says which. [opt in with webmcp: "name" on the call; dispatches poetry--core--composer#send]
- tool stop (mutating) - Stop the reply that is being written, as a press of Stop would. [opt in with webmcp: "name" on the call; dispatches poetry--core--composer#stop]
- RULE: Client-side accept, size and count limits are advisory: validate the attachment on the model as well.
- RULE: The SERVER holds the running state: render status: from your record (:idle, :running, :stopping) and redraw the slot alone with poetry_composer_action(id:, status:) in a Turbo Stream replace of "<id>-action" - never replace the form or the field, the draft lives there.
- RULE: Send every status change down ONE ordered channel (the broadcast), or pass version: and use a versioned replace - a form's answer and a broadcast can arrive out of order and leave Stop on screen.
- RULE: stop_url: is a POST endpoint that asks the reply to stop; a status other than :idle needs it. The Stop button submits a form of its own, so the draft is never sent with it.
- RULE: Refuse a send on the server while a reply runs (answer 409 or 422): the field keeps its text whenever the answer is not a success, and clears the sent text when it is.
- RULE: Block content is the tools row beside Send (a model picker, a mode toggle) - buttons there are type: :button so they never submit the message.
- RULE: Files in a message are attachments: true - the paperclip, drop, paste and the chips are the composer's own; never put a FileInput or a hand-rolled file button in the tools row. The files arrive under attachments_name: ("attachments[]"), or as signed ids with direct_upload: true.
- RULE: accept:, max_size: and max_files: refuse a file at intake and are advisory: validate the attachment on the model as well.
- RULE: A mention or command menu is composer.with_menu(trigger:, label:) with menu.with_item per option: the server renders every option and the composer filters them as the word is typed. Never hand-roll a popup over the field or swap the textarea for an editable div.
- RULE: What a menu sends is plain: a text menu leaves "@value " in the message (or the item's insert:), a chip menu (inserts: :chip, name:) posts the chosen values as hidden fields under name: and leaves the text clean. Never invent bracket or directive syntax for a reference, and look the handle or the value up again on the server.
- RULE: A menu too large to render with the page takes src: (an address) and the view there answers with poetry_composer_menu_options and one with_item per match: the server decides what matches and the order, and Turbo carries the request. Never fetch options with hand-written JavaScript, and scope the answer to what the person may see, as with any search endpoint.
- RULE: Commands: at: :start opens the menu only on the message's first word; insert: "/summarize " leaves text the server reads from the start of the message, and run: true takes the typed word out and only reports the choice (the poetry:composer-menu:choose event).
- RULE: A suggested prompt (a chip under an empty conversation, a quick reply) is poetry_composer_prompt(composer: "<id>", text:): pressed, the composer writes the text and sends it through its own gate; submit: false only writes it. Never reach into the composer's controller or set the field's value from page script.
- RULE: webmcp: "name" lets an in-page agent write the text, send and stop through the composer's own gate; leave it off unless the page means an agent to speak for the person.
- RULE: name: is the message's param key; label: is the field's accessible name - the placeholder is not a label.

## message (`poetry_message`)

A chat row pairing an author and avatar with message content.

Class: Poetry::Ui::Message::Component - BEM block `poetry-ui-message`.
- `align:` (symbol) - one of start|end, default "start" - Which side the row sits on; :end mirrors it for the local user's side.
Slots: avatar (The sender's avatar, kept beside the content column - decorative context; put meaningful sender identity in the header.), header (The sender identity line above the bubbles.), footer (Timestamps / delivery state below the bubbles.).
- PART `message` - The chat-row root - avatar plus a content column; align: :end mirrors the row for the local user's side | states: data-align=start|end (always - the resolved align)
- PART `message-avatar` - The avatar slot's box, kept out of the content column
- PART `message-content` - The content column - header, the body block (the Bubbles), footer
- PART `message-header` - Sender identity line above the bubbles (header slot)
- PART `message-footer` - Timestamps / delivery state below the bubbles (footer slot - it lifts the avatar)
In blocks: `chat` - for a screen, start from the block (MCP compose/describe_block, or `bin/rails g poetry:block`), not from scratch.
- RULE: One Message per turn: avatar slot + header/footer slots; the body block holds the Bubbles.
- RULE: align: :end is the local user's side - set it on the Message, never on the Bubbles inside.
- RULE: The avatar slot is decorative context by default - pass meaningful sender identity in the header.
- RULE: Timestamps and delivery state belong in the footer slot (it lifts the avatar automatically).

## message_scroller (`poetry_message_scroller`)

A streaming-aware transcript that keeps the latest message in view.

Class: Poetry::Ui::MessageScroller::Component - BEM block `poetry-ui-message_scroller`.
- `auto_scroll:` (boolean) - default true - Follows the newest message while the reader sits at the bottom; scrolling up releases the follow. Composes with anchor: true turns - a new anchored turn holds at the reading line while its reply streams, and following takes over once the reply fills the viewport.
- `content_id:` (string) - default "dynamic" - The content element's dom id - the Turbo Stream append target; defaults to "<id>-messages".
- `default_scroll_position:` (symbol) - one of start|end|last-anchor, default "end" - Where the viewport lands on connect: the newest message (:end), the oldest (:start), or the last anchor: true row (:"last-anchor").
- `id:` (string) - required - The transcript's stable identifier - the content element renders dom id "<id>-messages" for Turbo Streams to target (content_id: overrides it).
- `jump_button:` (boolean) - default true - Renders the floating jump-to-latest button (shown once the reader leaves the bottom).
- `preserve_scroll_on_prepend:` (boolean) - default true - Keeps the reading position stable when history prepends into the content element.
- `track_visibility:` (boolean) - default false - Opt-in observation of which rows are on screen - emits a visibility event as the visible set changes.
- PART `message-scroller` - The transcript root the controller drives - runtime scroll state is mirrored here | states: data-mode=following-bottom|free-scrolling|anchored-to-message|settling-jump (always once connected - the 4-state machine); data-scrollable (overflow exists - carries which edges have room (start, end, or both as a space-separated pair); end stays off while following the bottom, which is already closing the gap); data-autoscrolling (a programmatic scroll is settling - the follow-bottom release is suppressed while set); data-pending-scroll (the opening-position hold - rendered for default_scroll_position :end / :"last-anchor", cleared once the position lands (at once for an empty transcript))
- PART `message-scroller-viewport` - The native scroll region (role=region, focusable) - the controller mirrors the same runtime attributes here | states: data-scrollable (overflow exists - the same edge tokens as the root); data-autoscrolling (a programmatic scroll is settling); data-pending-scroll (the opening-position hold (the root's) - the dictionary hides the viewport while it is set)
- PART `message-scroller-content` - The row container and Turbo Stream append target (stable dom id <id>-messages); role=log announces additions
- PART `message-scroller-item` - One transcript row (poetry_message_scroller_item) - the id is how anchoring and Streams find it | states: data-message-id (always - the row's message id); data-scroll-anchor (anchor: true - the turn the controller holds at the reading line)
- PART `message-scroller-spacer` - Tail spacer faking scroll room below a short anchored turn - hidden at height 0
In blocks: `chat` - for a screen, start from the block (MCP compose/describe_block, or `bin/rails g poetry:block`), not from scratch.
- WIRING root: `poetry--core--message-scroller` registers; values auto_scroll, default_scroll_position, preserve_scroll_on_prepend, track_visibility
- WIRING viewport: `poetry--core--message-scroller` targets viewport
- WIRING content: `poetry--core--message-scroller` targets content
- WIRING spacer: `poetry--core--message-scroller` targets spacer
- WIRING jump_button: `poetry--core--message-scroller` actions scrollToEnd; targets button
- RULE: Stream by UPDATING a row's text (morph/replace) - appending nodes per token re-announces the row to AT.
- RULE: Rows are poetry_message_scroller_item(id: message.id) - the id is how anchoring and Streams find them; dom_id: gives the row a DOM id (dom_id(message)) for replace/morph streams.
- RULE: Append new turns with a Turbo Stream targeting the content element's dom id - content_id:, "<id>-messages" by default.
- RULE: History loads PREPEND into the content element - the controller preserves the reading position.
- RULE: Never nest a second scroll container inside the viewport.

## trace (`poetry_trace`)

Class: Poetry::Ui::Trace::Component - BEM block `poetry-ui-trace`.
Slot REQUIRED: with_step (at least one step (with_step(title, ...))) - a call without it raises.
Slots: steps (One step: the title (positional), optional icon:, description:, status: (:running, :error, :pending), href: (a link), and open: for a step with detail - the detail is the block, which makes the step a disclosure.; many; with_step yields NOTHING to the block - no |param|, write content directly).
- PART `trace` - The column of steps
- PART `trace-line` - One step's row - its icon, title and description | states: data-status=running|error|pending (status: - the step's state (absent when done))
- PART `trace-icon` - The step's glyph, and the disclosure's chevron (aria-hidden)
- PART `trace-title` - The step's words - shimmers while running
- PART `trace-description` - The muted trailing note - a duration, a count
- PART `trace-collapsible` - A step with detail - the state controller's root | states: data-open (the detail is shown (server-rendered from open:; the controller flips the pair)); data-closed (the detail is hidden)
- PART `trace-collapsible-trigger` - The disclosure button around the step's line - mirrors aria-expanded
- PART `trace-collapsible-content` - The detail panel - its height animates over the measured --collapsible-panel-height | states: data-open (the detail is open or entering); data-closed (the detail is closed or animating out (hidden lands after the exit)); data-starting-style (the first painted frame of an entry (controller-written)); data-ending-style (the whole exit, until hidden lands (controller-written))
- PART `trace-collapsible-content-inner` - The detail itself - indented on the theme's rail
In blocks: `chat` - for a screen, start from the block (MCP compose/describe_block, or `bin/rails g poetry:block`), not from scratch.
- WIRING collapsible: `poetry--core--state` registers
- WIRING collapsible_trigger: `poetry--core--state` actions toggle on click; targets trigger
- WIRING collapsible_content: `poetry--core--state` targets content
- RULE: The steps an agent takes (reasoning, tool calls, searches, a plan) are a Trace - never a hand-rolled column of muted rows.
- RULE: with_step(title, icon:, description:, status:) is one line; a block makes it a disclosure that reveals the detail (tool output in a poetry_code_block size: :sm, a reasoning summary).
- RULE: Map a tool call's state to status: and to the title's words: running -> status: :running, "Running ..."; failed -> status: :error, "Failed to run ..."; waiting -> status: :pending; done -> no status, "Ran ...". The title is what assistive tech reads.
- RULE: href: makes a step a link (a source, a file the agent changed).


