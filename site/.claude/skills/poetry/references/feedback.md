# poetry feedback components

Contracts generated from the registry. `RULE` lines are constraints,
not suggestions. Options are keywords; content is the block.

## alert (`poetry_alert`)

Class: Poetry::Ui::Alert::Component - BEM block `poetry-ui-alert`.
- `variant:` (symbol) - one of default|destructive, default "default", required
Slots: icon (takes poetry_icon props, not a block), title.
- PART `alert` - The callout root - role rides the variant (destructive announces assertively via role=alert; default is a polite role=status) | states: data-variant=default|destructive (always - the resolved variant)
- PART `alert-title` - The heading line, rendered when the title slot is set
- PART `alert-description` - The body copy - the content block renders here
In blocks: `destructive-panel` - for a screen, start from the block (MCP compose/describe_block, or `bin/rails g poetry:block`), not from scratch.
- RULE: Use poetry_alert for inline callouts - it carries role/aria-live; never a hand-rolled div.
- RULE: destructive announces assertively (role=alert) - reserve it for errors, not emphasis.

## deferred (`poetry_deferred`)

Class: Poetry::Ui::Deferred::Component - BEM block `poetry-ui-deferred`.
- `loading:` (symbol) - default "lazy"
- `src:` (string) - required
- PART `deferred` - The <turbo-frame> root - src is armed at connect(); failure is a state reflected here, never silent blankness | states: data-error (a frame fetch failed (error response, missing frame, or network error) - the controller stamps the error card; retry clears it)
- PART `deferred-error` - The retryable error card, stamped into the frame from the slotted <template> on failure
- WIRING `poetry--core--deferred`: targets error, placeholder; values src; actions retry
- RULE: Use poetry_deferred(src:) for expensive regions - never a spinner div + a hand-rolled fetch.
- RULE: loading: :lazy (the default) fetches on visibility: a deferred region inside a hidden Tabs panel (with_tab defer:) or HoverCard (defer:) loads on first reveal for free.
- RULE: The block is the placeholder (a Skeleton renders when absent); failure shows a retryable error card automatically - never hand-wire loading or error states around it.

## progress (`poetry_progress`)

Class: Poetry::Ui::Progress::Component - BEM block `poetry-ui-progress`.
- `label:` (string) - required
- `max:` (integer) - default 100
- `show_value:` (boolean) - default true
- `value:` (integer) - required
- PART `progress` - Root (role=progressbar, aria-value* and the accessible name) - label, value readout, and track stack here
- PART `progress-label` - The visible caption span (label:)
- PART `progress-value` - The tabular percent readout - renders unless show_value: false
- PART `progress-track` - The full-width rail the indicator fills
- PART `progress-indicator` - The filled bar - sized by an inline width percentage computed from value:/max:
- RULE: label: is REQUIRED - it is the progressbar's accessible name and the visible caption.
- RULE: value: is the current progress (0..max:, default max 100); the component computes the width.
- RULE: For an UNKNOWN duration use Spinner, not Progress - this bar is determinate.

## skeleton (`poetry_skeleton`)

Class: Poetry::Ui::Skeleton::Component - BEM block `poetry-ui-skeleton`.
- PART `skeleton` - The pulsing placeholder box itself - sized entirely by utility classes
- RULE: Skeleton is a loading placeholder - size it with classes (h-4 w-32); it has no content of its own.
- RULE: Mark the live region that will replace it (aria-busy on the container), not the skeleton.

## spinner (`poetry_spinner`)

Class: Poetry::Ui::Spinner::Component - BEM block `poetry-ui-spinner`.
- `label:` (string) - default "Loading"
- PART `spinner` - The spinning <svg> itself (the lucide loader-circle) - announces as role=status with aria-label from label:
- RULE: Spinner announces itself (role=status + aria-label) - never a bare spinning div.
- RULE: Set label: for the loading context ('Saving…'); the default is 'Loading'.

## toast (`poetry_toast`)

Class: Poetry::Ui::Toast::Component - BEM block `poetry-ui-toast`.
Slot REQUIRED: with_title (the message) - a call without it raises.
- `variant:` (symbol) - one of default|success|info|warning|destructive, default "default", required
- `closable:` (boolean) - default true
- `duration:` (integer)
- `politeness:` (symbol) - one of polite|assertive, default "dynamic"
Slots: title, description, action (takes poetry_button props, not a block; with_action yields NOTHING to the block - no |param|, write content directly).
- PART `toast` - The notification item itself (<li>, role=status) - variant, open state, and the toaster's stack facts all ride here | states: data-open (toast is showing (the server-rendered state; the dismiss exit flips the pair before removal)); data-closed (toast is animating out); data-variant=default|success|info|warning|destructive (always - the resolved variant); data-queued (the toaster holds it hidden past the visible limit (timer paused until a slot frees up)) | vars: --poetry-toast-index (stack position written by the toaster's reflow (newest visible toast = 0))
- PART `toast-icon` - The variant's icon well (aria-hidden; the default variant renders none)
- PART `toast-title` - The message - the announced payload's first line (required slot)
- PART `toast-description` - Supporting copy under the title
- WIRING `poetry--core--toast`: targets action, close; values duration, politeness; actions dismiss, pause, resume; events poetry:toast:dismiss, poetry:toast:show
- RULE: Server-side toasts go through turbo_stream.poetry_toast / the flash recipe - never hand-append into #poetry-toaster.
- RULE: Undo/consequence toasts MUST carry an action slot - action-bearing toasts default to persistent (duration nil); give an explicit duration only when missing the action is safe.
- RULE: variant: :destructive is for failures the user must hear about (it announces ASSERTIVELY); do not use it for styling.
- RULE: Never put required interactions in a toast (toasts are missable) - that is AlertDialog.
- RULE: Toasts are supplementary: never the only place an outcome is recorded.

## toaster (`poetry_toaster`)

Class: Poetry::Ui::Toaster::Component - BEM block `poetry-ui-toaster`.
- `position:` (symbol) - one of top-left|top-center|top-right|bottom-left|bottom-center|bottom-right, default "bottom-right", required
- `hotkey:` (string) - default "F8"
- `limit:` (integer) - default 3
- PART `toaster` - The toast viewport itself (<ol>, role=region, data-turbo-permanent) - the corner geometry and the Turbo Stream append target ride here | states: data-position=top-left|top-center|top-right|bottom-left|bottom-center|bottom-right (always - the corner; each toast's slide direction keys off it via group/toaster)
- WIRING `poetry--core--toaster`: targets item; values hotkey, limit, position; actions focusRegion, reflow
- RULE: Exactly ONE poetry_toaster per layout; it is data-turbo-permanent.
- RULE: Server-side toasts go through turbo_stream.poetry_toast / the flash recipe - never hand-append into #poetry-toaster.
- RULE: Do not announce() toast content yourself - the toast controller already does; double-announcing is a regression.

