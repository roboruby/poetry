# deciding - which component

Match the INTERACTION MODEL first - what the user does - and the
visual treatment second. The look is the theme's job; the
component's job is behavior. When a whole screen is the brief,
the `compose` MCP tool routes to a vetted block BEFORE any of
this (see `references/blocks.md`).

## Options are VALUES vs options DO things

- Choosing writes a form value: Select (closed pick),
  NativeSelect (zero-JS forms), Combobox (filter to pick),
  Combobox `multiple:` (pick several - chips), RadioGroup (few
  always-visible exclusive choices), ToggleGroup `type: :single`
  (exclusive UI state, no form machinery).
- Choosing runs an action: DropdownMenu (per-item actions),
  ContextMenu (right-click/long-press), Menubar (app-wide command
  strip), Command (searchable palette).
- The rule: if the choice submits, it is never a menu; if it
  navigates or mutates, it is never a select.

## Overlays

- Dialog: interrupt for a task; focus trapped; explicit close.
- AlertDialog: confirm a destructive or irreversible act - no
  light dismiss, the cancel action is the default focus.
- Sheet: a side panel for secondary work while the page stays
  visible; Drawer: the bottom-edge mobile-first surface.
- Popover: a light-dismiss micro-surface anchored to its trigger.
- HoverCard: a hover PREVIEW - never interactive controls.
- Tooltip: one line of labeling; never actions, never required
  information.

## Chips, toggles, badges

- Exists until removed (recipients, filters): TagGroup.
- On/off UI state: Toggle; exclusive set: ToggleGroup.
- Picked from options: Combobox `multiple:` (its chips remove
  back into the option list; TagGroup chips are just gone).
- Static status: Badge - never clickable.

## Quantity, progress, waiting

- A quantity within a known range (disk, seats, strength): Meter.
- An operation completing over time: Progress (determinate only).
- Unknown duration: Spinner; structure-shaped waits: Skeleton;
  Turbo-loaded regions: Deferred.

## Text and value entry

- One line: Input; multi-line: Textarea; search: SearchField
  (Escape clears, the clear affordance rides it).
- Fixed format: Input `mask:`; numbers: NumberField; one-time
  codes: InputOtp.
- Dates and times: DateField / TimeField (segmented editing);
  DatePicker when a calendar aids the pick; Calendar alone for
  in-page selection; Slider / range for magnitudes.
- File upload: FileInput (`variant: :dropzone` when dragging is
  the point).

## Structure and records

- Tabular records with sort/filter/page: DataTable
  (server-driven URL state); plain semantics: Table.
- Label:value facts on a detail page: MetadataList; one KPI:
  Stat; grouped content: Card; freeform rows: Item.
- Hierarchy that expands and collapses: Tree; app navigation:
  Sidebar (shell) / NavigationMenu (site) / Tabs (views of one
  thing); progressive disclosure: Accordion (a one-off:
  Collapsible).
- Grouped controls in ONE Tab stop: Toolbar; visually fused
  buttons: ButtonGroup.

## When two still fit

Prefer the narrower component (Stat over a hand-built Card;
SearchField over Input-plus-button), and prefer the one whose
KEYBOARD contract matches what the user expects to press. If the
answer still is not obvious, the block catalog probably already
composed it - check `references/blocks.md` before building.
