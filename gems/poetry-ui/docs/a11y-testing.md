# Manual accessibility testing protocol

The axe walk (`rake test:accessibility`) is automated, runs on every gate, and
catches roughly 30–40% of WCAG issues — the structural ones. The rest live in
focus management, screen-reader announcements, and keyboard operability of
interactive widgets, and only a human at a keyboard finds them. This is that
protocol.

**When:** before a release-grade milestone, and whenever an interactive
component's controller or ARIA surface changes. The automated pass runs first,
always; the manual passes below assume it is green.

## The automated pass first

```bash
bundle exec rake test:accessibility            # default theme
POETRY_THEME=rhea bundle exec rake test:accessibility   # per-theme re-run
```

Axe (wcag2a + wcag2aa) walks every registry component's preview examples —
the same corpus the goldens screenshot, so a state with no preview has no axe
coverage either (the declared-axis coverage gate keeps that honest). Contrast differs
per theme; run at least the default and one tinted-surface port (rhea) before
a release. `POETRY_AXE_SKIPS` in `rakelib/browser.rake` is the ONLY skip
mechanism — every entry carries the measured value and the review reason, and
stale skips fail the task. No silent skips.

Axe sees **initial render state only**. Open overlays, mid-stream updates, and
everything below are the manual protocol's job.

## Setup

- **macOS — VoiceOver:** toggle **⌘+F5**. Navigate **Ctrl+Option (VO) +
  arrows**; rotor **VO+U** (headings / landmarks / form controls); interact
  with a group **VO+Shift+Down**.
- **Windows — NVDA** (free; the realistic baseline for real users): arrows in
  browse mode, **Tab** between controls, **NVDA+Space** to toggle browse/focus
  mode, **NVDA+F7** for the elements list.
- Preview surface: Lookbook (`/lookbook`) or the docs site — both render the
  registry corpus. Test **light and dark**, and at **200% browser zoom**
  (WCAG 1.4.4), and with **reduced motion** on (System Settings →
  Accessibility → Display → Reduce motion).
- Keyboard only for the keyboard passes — ignore the mouse entirely.

## Universal checks (every component)

- [ ] **Tab order** matches visual order; nothing interactive is skipped or
      trapped (modal focus traps are intentional — Escape must release).
- [ ] **Focus is always visible** — poetry styles `focus-visible` rings on
      every focusable part; confirm the ring survives theme ports.
- [ ] **Accessible name** on every control — never "button", "blank",
      "edit text".
- [ ] **State announced** — checked / expanded / selected / disabled /
      invalid changes are spoken as they happen.
- [ ] **200% zoom + reduced motion**: no content or function lost; nothing
      animates against the preference (presence transitions respect it).

## Pattern checklists

Group components by pattern and run the pattern's checks against each. The
registry is the roster — `config/component_registry.yml` enumerates it; the
groups below name today's members so drift is visible in review.

### 1. Form controls

`button, button_group, checkbox, combobox, date_field, date_picker, calendar,
field, file_input, input, input_group, input_otp, label, native_select,
number_field, radio_group, search_field, select, sensitive_input, slider,
switch, tag_group, textarea, time_field, toggle, toggle_group`

- [ ] Every control has a name — visible label association (`field` wires
      this), or an explicit `aria-label` where the pattern is icon-only.
- [ ] **checkbox / switch / toggle**: Space toggles; "checked" / "on" /
      "pressed" announced.
- [ ] **radio_group / toggle_group**: roving tabindex (one tab stop), arrows
      move selection, the group itself is named.
- [ ] **select / native_select / combobox**: Enter/Space + arrows open and
      move; typeahead works; selection announced; Escape closes; combobox
      (incl. `multiple`) announces filtered result counts via its live
      region.
- [ ] **number_field**: announced as a spinbutton with min/max/now;
      ArrowUp/Down and PageUp/Down step; the mask `input` still exposes the
      underlying value.
- [ ] **slider**: arrows + Home/End step; each thumb announces
      value/min/max; range mode names both thumbs.
- [ ] **input_otp**: typing advances slots, paste fills, the group carries
      one name, every slot reachable.
- [ ] **date_field / time_field / date_picker / calendar**: segments
      announce their role and value; the calendar grid is a `grid` — arrows
      move by day, PageUp/Down by month; selected/today announced; a range
      submits both `name[start]` and `name[end]` and announces both ends.
- [ ] **file_input / attachment**: the dropzone opens the picker with
      Enter/Space; list changes are announced; attachment remove buttons are
      named per file.
- [ ] **sensitive_input**: the reveal toggle is named, announces
      pressed/state, and never leaks the value to the a11y tree while
      masked.
- [ ] **Invalid state**: invalid controls announce it and the error text is
      associated via `aria-describedby` (the `field` contract).

### 2. Overlays

`dialog, alert_dialog, command/dialog, sheet, drawer, popover, hover_card,
tooltip`

- [ ] Opening moves focus in; closing returns focus to the trigger — also
      after a Turbo visit and after a bfcache restore (the cache-restore bug class).
- [ ] Focus is trapped while modal; **Escape closes**; backdrop behavior
      matches the component contract (alert_dialog: no click-outside
      dismiss, initial focus on the safe action).
- [ ] `role="dialog"` / `"alertdialog"` + `aria-modal`, labelled by the
      title, described by the body.
- [ ] Background content unreachable while modal (Tab and the VO cursor).
- [ ] **tooltip / hover_card**: appear on focus, not just hover; Escape
      dismisses; content is announced.

### 3. Menus and command

`dropdown_menu, context_menu, menubar, navigation_menu, command`

- [ ] Trigger opens with Enter/Space/ArrowDown; focus lands on the first
      item; Up/Down move; typeahead jumps; Right/Left traverse submenus;
      Escape closes and returns focus.
- [ ] Items announce `menuitem` / `menuitemcheckbox` / `menuitemradio` +
      checked state.
- [ ] **context_menu**: also opens via Shift+F10 / the context-menu key.
- [ ] **menubar**: arrow keys traverse the bar; open menus follow the
      hovered/focused bar item.
- [ ] **command**: typing filters, arrows + Enter select, result count is
      announced; inside command/dialog the overlay checks above apply too.

### 4. Disclosure and navigation

`accordion, collapsible, tabs, breadcrumb, pagination, sidebar`

- [ ] **accordion / collapsible**: the trigger is a button with
      `aria-expanded`; state changes announced; accordion triggers sit in
      headings at the declared level.
- [ ] **tabs**: roving tabindex, arrows move, `tab`/`tabpanel` roles hold,
      the active tab is announced, the panel is reachable.
- [ ] **breadcrumb / pagination**: `nav` landmarks with names; the current
      page carries `aria-current="page"`.
- [ ] **sidebar**: the toggle is named; active item `aria-current`;
      collapsed-rail tooltips reachable by keyboard; the mobile sheet traps
      focus (the DOM-move adoption must not strand focus).

### 5. Composite

`table (+ selection + action_bar), data_table, tree, toolbar, resizable,
carousel, scroll_area`

- [ ] **table / data_table**: real `<table>` semantics; sortable headers
      announce `aria-sort`; selection checkboxes are named per row; the
      action_bar appearing on selection is announced and reachable; sticky
      headers don't hide focused cells.
- [ ] **tree**: `tree` / `treeitem` roles; arrows navigate, Right/Left
      expand/collapse; selection announced; every node named.
- [ ] **toolbar**: one tab stop, arrows move inside, groups named.
- [ ] **resizable**: the handle is a named `separator`; arrows resize
      within min/max.
- [ ] **carousel**: prev/next are named buttons; slide changes announced
      via the live region; fully keyboard-operable.
- [ ] **scroll_area**: content reachable and scrollable by keyboard.

### 6. Display and feedback

`alert, aspect_ratio, avatar, badge, bubble, card, clipboard_text,
code_block, deferred, empty, icon, item, kbd, link, marker, metadata_list,
meter, progress, separator, skeleton, spinner, stat, toast, toaster,
typeset`

- [ ] **toast / toaster**: server-spawned toasts
      (`turbo_stream.poetry_toast`) announce via the toaster's live region;
      pause-on-hover holds timers; the dismiss button is named; the stack
      reflow respects reduced motion.
- [ ] **alert**: `role="alert"` only where interruption is warranted.
- [ ] **progress / meter / spinner**: announce role + now/min/max + a name;
      spinner has `role="status"` without announcement spam.
- [ ] **skeleton / deferred**: busy state exposed once, not per node; the
      resolved content announces its arrival.
- [ ] **icon**: decorative by default (`aria-hidden`); a standalone icon
      carries `label:` → `role="img"` + `aria-label` (the component
      contract — verify both paths).
- [ ] **clipboard_text**: the copy action announces success; the value is
      readable before copying.
- [ ] **avatar / marker / badge**: decorative images `alt=""`; meaningful
      ones named; fallbacks give a name.
- [ ] **separator**: decorative → hidden from the tree; semantic →
      `separator` role.
- [ ] **typeset / code_block**: prose and code reachable in browse mode;
      code blocks scroll without trapping.

### 7. Streaming and charts (poetry-specific)

`message, message_scroller` + `poetry-charts`

- [ ] **message_scroller**: streamed updates MORPH a row, never append per
      token — confirm the row is announced once per settled update, not
      re-announced per delta; stick-to-bottom does not steal the reading
      cursor; the jump button is named and reachable mid-stream.
- [ ] **charts**: the accessibility layer holds — keyboard focus moves
      across data points, values are announced, and the SVG carries its
      title/description for AT.

## Recording results

Log each finding as `component · check · AT (VoiceOver/NVDA) · severity ·
note`. A finding that axe COULD see becomes a fix or a reviewed
`POETRY_AXE_SKIPS` entry — never an undocumented skip. A finding only the
manual pass can see gets a wiring/dommy test where the tier allows (the
testing doctrine in [testing.md](testing.md): the cheapest tier that can
catch the regression), and a browser test only when it genuinely needs a
layout engine or a real AT interaction.
