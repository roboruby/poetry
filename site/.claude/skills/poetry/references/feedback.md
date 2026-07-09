# poetry feedback components

Contracts generated from the registry. `RULE` lines are constraints,
not suggestions. Options are keywords; content is the block.

## alert (`poetry_alert`)

Class: Poetry::Ui::Alert::Component - BEM block `poetry-ui-alert`.
- `variant:` (symbol) - one of default|destructive, default "default", required
Slots: icon (takes poetry_icon props, not a block), title.
- RULE: Use poetry_alert for inline callouts - it carries role/aria-live; never a hand-rolled div.
- RULE: destructive announces assertively (role=alert) - reserve it for errors, not emphasis.

## deferred (`poetry_deferred`)

Class: Poetry::Ui::Deferred::Component - BEM block `poetry-ui-deferred`.
- `loading:` (symbol) - default "lazy"
- `src:` (string)
- WIRING `poetry--core--deferred`: targets error, placeholder; values src; actions retry
- RULE: Use poetry_deferred(src:) for expensive regions - never a spinner div + a hand-rolled fetch.
- RULE: loading: :lazy (the default) fetches on visibility: a deferred region inside a hidden Tabs panel (with_tab defer:) or HoverCard (defer:) loads on first reveal for free.
- RULE: The block is the placeholder (a Skeleton renders when absent); failure shows a retryable error card automatically - never hand-wire loading or error states around it.

## progress (`poetry_progress`)

Class: Poetry::Ui::Progress::Component - BEM block `poetry-ui-progress`.
- `label:` (string)
- `max:` (integer) - default 100
- `show_value:` (boolean) - default true
- `value:` (integer) - required
- RULE: label: is REQUIRED - it is the progressbar's accessible name and the visible caption.
- RULE: value: is the current progress (0..max:, default max 100); the component computes the width.
- RULE: For an UNKNOWN duration use Spinner, not Progress - this bar is determinate.

## skeleton (`poetry_skeleton`)

Class: Poetry::Ui::Skeleton::Component - BEM block `poetry-ui-skeleton`.
- RULE: Skeleton is a loading placeholder - size it with classes (h-4 w-32); it has no content of its own.
- RULE: Mark the live region that will replace it (aria-busy on the container), not the skeleton.

## spinner (`poetry_spinner`)

Class: Poetry::Ui::Spinner::Component - BEM block `poetry-ui-spinner`.
- `label:` (string) - default "Loading"
- RULE: Spinner announces itself (role=status + aria-label) - never a bare spinning div.
- RULE: Set label: for the loading context ('Saving…'); the default is 'Loading'.

## toast (`poetry_toast`)

Class: Poetry::Ui::Toast::Component - BEM block `poetry-ui-toast`.
- `variant:` (symbol) - one of default|success|info|warning|destructive, default "default", required
- `closable:` (boolean) - default true
- `duration:` (integer)
- `politeness:` (symbol) - one of polite|assertive, default "dynamic"
Slots: title, description, action.
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
- WIRING `poetry--core--toaster`: targets item; values hotkey, limit, position; actions focusRegion, reflow
- RULE: Exactly ONE poetry_toaster per layout; it is data-turbo-permanent.
- RULE: Server-side toasts go through turbo_stream.poetry_toast / the flash recipe - never hand-append into #poetry-toaster.
- RULE: Do not announce() toast content yourself - the toast controller already does; double-announcing is a regression.

