# Testing poetry components

The doctrine a host app (or an agent working in one) adopts to test UI built
with poetry. It is the same split poetry uses on itself — distilled from the
component build-out — and it exists so that **a failing test names the fix**,
not just the symptom.

## The three tiers

Test at the cheapest tier that can catch the bug. Most UI bugs are structural
(wrong attribute, missing wiring) and belong in the fast tiers; reserve the
browser for what genuinely needs a layout engine.

### 1. Wiring tests (render + assert markup) — milliseconds

Render the component and assert the **contract**, not the classes: the
`data-slot` parts, the ARIA attributes, the form participants, and the
Stimulus wiring (`data-controller` / `data-action` / `data-*-target`).

```ruby
fragment = render_inline(Poetry::Ui::Checkbox::Component.new(name: "terms"))
control  = fragment.css('[data-slot="checkbox"]').first

assert_equal "checkbox", control["role"]
assert control.css('input[type="checkbox"]').any?, "a native input participates in the form"
```

Assert against **`data-slot`**, never against Tailwind classes — classes are
an implementation detail that a token retune or a Base UI vocabulary change
 will move; the slot vocabulary is the stable contract.

The Ruby↔JS seam is guarded for free: every Stimulus token a component
renders is checked against the introspected controllers manifest (a rename
can never silently strand wiring). You get the same guarantee on your OWN
templates by running `poetry check` (below).

### 2. Behavior tests (the dommy tier) — sub-second, headless

For interaction — a click flips state, arrows move focus, a form serializes —
drive the **real component markup + real compiled CSS + real Stimulus
controllers** through a headless DOM (dommy). This catches the bug classes a
unit test can't see (UA stylesheet semantics, the dark-mode cascade, a purged
class) without paying for a browser.

```ruby
harness = render_in_dommy(Poetry::Ui::Checkbox::Component.new(name: "terms"))
harness.execute(<<~JS)
  document.querySelector('[data-slot="checkbox"]').dispatchEvent(new MouseEvent("click", { bubbles: true }));
JS
harness.pump(rounds: 10)

assert_equal "true", harness.evaluate(%(document.querySelector('[data-slot="checkbox"]').getAttribute("aria-checked")))
assert_no_js_errors harness
```

Query by `data-slot` here too. When you must select by a poetry class that
contains a `:` (a variant like `data-open:...`), use the **token-safe
attribute form** `[class~="data-open:..."]` — a bare `.data-open\:...`
selector has fragile escaping; the `[class~=]` form has identical `(0,1,0)`
specificity and no escaping hazard.

### 3. Browser pass (real Chrome) — seconds, per milestone

Reserve the browser for what only a layout engine can answer: pointer drag
geometry, focus return across a portal, `:has()` / anchor positioning,
scroll-linked effects. Drive it with real synthetic events and remember the
platform truths the fast tiers hide:

- `.click()` does not focus — focus first if the behavior depends on it.
- Press-to-open surfaces fire on **pointerdown**, not click.
- Assert the controller's **actual** state vocabulary (read the JS): open
  surfaces wear `data-open`, triggers `data-popup-open`, committed options
  `data-selected`, toggles `data-pressed` (Base UI).

Re-run `bin/rails generate poetry:install` + a Tailwind build before a browser
pass — a stale host safelist purges newly used dictionary classes.

## `poetry check` — the mechanical gate

Before any of the above, lint the source. `poetry check` herb-parses your ERB
and validates every poetry surface against the registry + manifest **without
rendering** — unknown component/option/variant (with did-you-mean), unknown
Stimulus controller/action/target, and raw-color classes:

```
bundle exec rake "poetry:check[app/views/**/*.html.erb]"
POETRY_CHECK_JSON=1 bundle exec rake "poetry:check[app/views/**/*.html.erb]"   # editor / CI
```

It exits non-zero on any error, and every finding names the fix. Run it in CI
and wire it into your agent loop: it is the cheapest, most self-correctable
signal you have, and it runs before a single component renders.

## What to assert, in one line

Assert the **contract** (slots, ARIA, form participation, wiring), never the
**classes**. The contract is what poetry promises to keep stable across token
retunes and primitive-vocabulary shifts; the classes are free to move under it.

## The design tier — slop is a tested property

Above the mechanical gate sits the taste tier (N14): `DesignLint`, twelve
deterministic design-slop rules, each citing its the design-rule analogue/the slop-gate analogue analogue
and naming the fix. Warnings, not errors — but the dogfood surfaces gate on
them staying at zero.

- **AST tier** (rides the same herb walk as `poetry check`, reads ERB and
  plain HTML alike): card-in-card, icon-tile-over-heading, wall-of-cards,
  off-scale arbitrary values, gradients off the token surface, heading
  skips, center-everything, shadow stacking.
- **DOM tier** (computed styles from the dommy tier — no browser): type-scale
  monotony, invisible adjacent surfaces, near-identical adjacent surfaces,
  and the stock-theme-while-a-brand-exists nudge.

```
bundle exec rake design:lint                    # both tiers over the gem's own surfaces
POETRY_CHECK_DESIGN=1 bin/rails poetry:check    # host apps: taste tier joins the linter
```

The default gate holds all three design surfaces: the component templates
(unit test), the 60+ rendered component pages (dommy test), and the nine
committed DESIGN.md exports (`design:verify`). The eval's `design_slop`
cross-arm gate runs the identical rules on every arm — the raw arms fail it
on genuine slop; the poetry arms pass.

## The eval tier — the thesis is a tested property

Above everything sits the harness that measures whether the system works at
all (completed): 31 frozen task pairs — a poetry arm and a
realistic raw-Tailwind arm per component family — scored two ways.

- **Mechanical** (deterministic, in the default gate): `rake eval:verify`
  asserts every poetry arm passes every cross-arm gate and every diagnostic,
  and every raw arm still fails at least one cross-arm gate — so the planted
  failure modes survive gate evolution. `rake eval:scorecard` prints the full
  card.
- **Judged** (on demand, never in CI): `rake eval:capture` screenshots both
  arms through the browser rig; `rake eval:judge` runs a blind, paired,
  position-swapped LLM judge whose verdicts commit under `eval/results/`.
  The frozen arms have known intended winners, so every judge run doubles as
  the judge's own calibration — its agreement rate is in the verdicts file.

Doctrine and cadence live in `eval/README.md`.
