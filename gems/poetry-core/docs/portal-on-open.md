# Portal-on-open: the popper family moves to body

Approved 2026-07-30 ("match upstream's architecture - we shouldn't be
diverging from it"). One mechanism, rolled out consumer by consumer.

**SHIPPED IN FULL 2026-07-30** - S0 through S5 landed in order (+ the
poetry-ui tester/dommy commits alongside each). Every popper consumer
portals; the headline
scroll-detach measurement went 40px -> 0px live. The decisions below
held; the shipped record at the bottom lists what the build ADDED to
them.

## Why

- **Scroll jiggle (the trigger for this build).** Fixed-strategy popups
  are viewport-pinned; page scroll moves the anchor on the compositor a
  frame before the main-thread reposition catches up. Measured live: a
  40px scroll step detaches the popup by the full 40px until the async
  `computePosition` write lands. Irreducible under `fixed` - nothing on
  the main thread beats the compositor.
- **Transformed ancestors** (the bubble-pill class, CSS gotchas ledger):
  any transform/filter/will-change ancestor becomes the containing block
  for fixed content and breaks anchoring. Body-portaled absolute content
  is immune.
- **Upstream parity.** Base UI portals popups to body and positions them
  `absolute` (verified on ui.shadcn.com: positioner `div.isolate.z-50`,
  `position: absolute`, direct child of a body-level wrapper). Static
  under scroll by construction.

**Verified non-problem:** the docs style switcher keeps ONE
`.style-<name>` class on `<html>` (never wrappers), so body-portaled
content keeps theming and tokens. Upstream ships zero ancestor-scoped
component CSS. Subtree-scoped HOST apps are covered by D2 below.

## Decisions

- **D1 - the mechanism is a shared helper, not presence.**
  `helpers/portal.js`: `portalContent(content, { container })` moves the
  content node to the container and leaves a placeholder comment at home;
  `restoreContent(content)` swaps it back. Consumers call these at the
  SAME seam as `#activateLayers` / `#removeControllers` (every popper
  consumer already has that symmetric pair). Presence helpers must NOT
  portal - they also serve dialogs, accordions, collapsibles, which must
  never move.
- **D2 - container resolution.** Default `document.body`. Override via
  `data-poetry-portal-container="<id>"` on the component root (the Base
  UI / Radix `container` prop, attribute-shaped) for subtree-scoped
  hosts.
- **D3 - strategy is coupled to placement.** In place -> `fixed`
  (today's behavior, goldens unchanged); portaled -> `absolute` (the
  jiggle fix). The consumer flips the popper's `strategyValue` when it
  portals/restores; popper re-resolves. Never ship absolute-in-place -
  it re-introduces overflow-clipping.
- **D4 - restore BEFORE Turbo caches, and on every close.** Close path:
  exit presence completes -> `restoreContent` in the same `onRemove` that
  already strips layer controllers. Safety net: a `turbo:before-cache`
  listener force-restores (and force-closes) any portaled content - the
  The Turbo cache-restore bug class, pre-empted. Restore guards
  `placeholder.isConnected` (a morph may have replaced the origin; then
  drop the node instead of stranding it).
- **D5 - the event bridge (the React-vs-DOM trap).** React portals keep
  bubbling through the COMPONENT tree; DOM portals do not. Once content
  lives under body, its `poetry:*` events no longer bubble through the
  component root, so host-app `data-action` wiring on the root goes
  deaf. The portal helper installs a re-dispatch bridge: bubbling
  `poetry:*` (and `poetry--core--*:`) events reaching the portaled
  content's boundary are re-dispatched (non-bubbling clone or
  home-anchored dispatch) from the placeholder's parent so root-level
  listeners keep firing. Internal programmatic listeners (`#listen(content, ...)`)
  ride the node and need nothing.
- **D6 - Tab order becomes owned behavior.** Portaled content sits at
  body, so natural Tab-out is gone. Apply the banked react-aria
  rule: Tab out of a NON-MODAL portaled overlay closes it and lands
  focus after the trigger in document order (Shift+Tab -> the trigger).
  Consumers that already close-on-Tab (combobox) keep their behavior -
  the landing spot is what changes. Modal (`modal: true`) keeps the
  focus-scope trap; nothing changes there.
- **D7 - out of scope.** NavigationMenu's viewport (a layout-flow panel,
  not an anchored popup - upstream keeps it inline too) and the whole
  `<dialog>` family (native top layer). Toasts already use the top-layer
  exemption.

## Rollout slices (each landed with full gates before the next)

- **S0 - mechanism.** SHIPPED. `helpers/portal.js` + popper
  strategy coupling + the event bridge + `turbo:before-cache` net.
- **S1 - tooltip + hover_card.** SHIPPED.
- **S2 - popover** (+ date_picker riding). SHIPPED.
- **S3 - select** (aligned mode rides unchanged). SHIPPED.
- **S4 - combobox** (both modes; D6 landed here). SHIPPED.
- **S5 - menu family** (dropdown, context menu, menubar). SHIPPED.
- **S6 - docs + ledger pass.** DONE: per-style + dark sweep green
  (portaled content themed in all styles, style flip live while open),
  theming doc gained the D2 container section, gotchas ledgers updated.

## The shipped record - what the build added to the plan

- **Popper content cache.** Stimulus targets unscope when content
  portals; the old fallback would have positioned the ROOT. Popper
  caches the resolved node while connected (S1).
- **One-frame-late pinned reconcile.** Connect order within a boot is
  unordered; portaling before the sibling popper's connect robs it of
  the target before it can cache. Server-pinned opens portal on rAF.
- **The first-open focus race fix** (pre-existing, surfaced by S2's
  live proofs): closed-era popper passes parked visibility:hidden
  inline, and Chrome silently refuses focus into a hidden subtree at
  the open microtask. The hide verdict now resolves visible while
  content.hidden.
- **The delegation pattern** (S4): Stimulus data-ACTIONS also unscope
  under a portal. A controller whose scope splits (engine home, parts
  portaled - combobox multiple) carries delegated listeners on the
  portaled node itself, guarded so in-scope elements stay the actions'
  job. The menu engine had this shape from birth.
- **The dir stamp** (S5): dir inherits through the DOM; a body portal
  flips a locally-RTL subtree back to the document direction.
  portalContent stamps the home-effective dir, restore un-stamps.
- **Bridge registration hardening** (S5): a boot path that never
  evaluates index.js's top level (the dommy flattener) got an EMPTY
  bridge list. registerPoetryControllers registers it too (idempotent).
- **Bridged event.target is the home anchor.** A DOM re-dispatch cannot
  fake target. Listeners above portaled content read detail.item (the
  documented payload) or the clone's portalTarget.
- **The test-scoping family** (five sightings): index pairing, tester
  root scoping, dommy state helpers, target scoping, action scoping -
  every trigger/content association must resolve through the id pair
  (aria-controls), never through document order or subtree scoping.
- **Parked, pre-existing, portal-unrelated:** the docs aligned-select
  example bails to popper positioning identically pre/post portal
  (A/B-confirmed) - why aligned doesn't engage there is an open
  question for another day.

### S7 (2026-07-31): sub levels portal too - the invisible-submenu correction

S5's "subs ride INSIDE the content" decision was wrong: a
position:absolute sub inside the root content is clipped by the
content's own `overflow-y-auto` scroller (fixed subs escaped ancestor
clipping pre-portal; upstream portals every sub level for exactly this
reason). Every submenu in the family opened INVISIBLE - data-open set,
popper positioned, painted behind the clip. No tier caught it: dommy has
no layout, no golden captures an open sub, and rect-based live checks
lie (getBoundingClientRect ignores clipping - hit-test with
elementFromPoint instead). Found by a user on the docs page.

The fix mirrors the root recipe per sub level (#showSub/#closeSubTree),
plus three seams the root never needed:
- **Native delegation rides the portaled node** (#wireSub): root-content
  bubbling is gone and item data-actions are out of scope; the
  dismissable pair is wired direct - its bridged home duplicate targets
  the wrapper, resolves no level, and no-ops.
- **The modal scrim is per-layer:** body pointer-events none + inline
  auto on each layer. The sub inherited the root layer's auto while
  inside it; portaled to body it carries its own.
- **focus-scope containment goes logical:** `logicallyContains` in
  portal.js follows placeholders home, so the trap keeps portaled sub
  levels (Radix scopes the trap over the React tree, which portals
  preserve; a DOM subtree check yanked focus straight back out).

## Per-slice acceptance

1. **Scroll-static proof (the headline):** with the popup open,
   `scrollBy(40)` then a SAME-TURN rect sample shows popup->anchor
   offset UNCHANGED (was: 40px detach). CDP, per consumer.
2. Goldens: open-state baselines pixel-identical (absolute coordinates
   must land where fixed ones did; any drift is a bug, not a re-bless).
3. vitest + dommy + rake + axe + tester tier green.
4. Turbo: morph with popup open -> no duplicate/stranded content;
   back-forward cache restore -> closed, content home.
5. Keyboard: Tab-out lands after the trigger; Escape/outside-press
   unchanged; focus return on close unchanged.

## Risks

- **Presence animations across the move:** portal BEFORE `enterPresence`
  (animation plays in the portal), restore AFTER exit completes - never
  mid-animation.
- **Stacking:** body-level `z-50` beats page stacking contexts; verify
  toast-over-popover ordering (top-layer exemption) still holds.
- **The style-scope wrappers claim is dead but hosts can still subtree-
  scope:** D2 is the documented answer; add it to the theming docs.
- **Anything reading `content.offsetParent`/ancestors** (measure code,
  select align?) must be audited in S0 - grep for offsetParent, closest
  over content ancestors.
