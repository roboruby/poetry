# Portal-on-open: the popper family moves to body

Approved 2026-07-30 ("match upstream's architecture - we shouldn't be
diverging from it"). One mechanism, rolled out consumer by consumer.

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
   cache-restore bug class, pre-empted. Restore guards
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

## Rollout slices (each lands with full gates before the next)

- **S0 - mechanism.** `helpers/portal.js` + popper strategy coupling +
  the event bridge + `turbo:before-cache` net. Vitest for: move/restore
  round-trip, placeholder-gone guard, container override, bridge
  re-dispatch, strategy flip.
- **S1 - tooltip + hover_card.** No focus machinery, pure anchoring -
  proves positioning + scroll-static with least choreography.
- **S2 - popover** (date_picker rides along - verify its close-on-pick).
- **S3 - select** (roving focus + typeahead; modal:true default).
- **S4 - combobox** (activedescendant session, chips/multiple, the
  show_clear X press = outside-press veto check).
- **S5 - menu family:** dropdown_menu, context_menu (point anchor),
  menubar (coordinator).
- **S6 - docs + ledger pass.** Docs pages re-verified per style + dark;
  gotchas notes updated (transformed-ancestor entry gains "fixed by
  portal"); memory + SETUP untouched (no operational change).

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
