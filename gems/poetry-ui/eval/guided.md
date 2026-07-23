# The guided-workflow eval

Pre-registration for the eval that tests whether the **guided `build_page`
workflow moves the composition score** where the design skill and the
`compose` tool-entry did not. Written before the run; the predictions
below are frozen once the first generation spends a token.

## The graded question

 fired the design skill in 24/31 arms and composition did not move.
 hit 31/31 `compose` tool-entry adoption and composition still missed.
The thesis is that the missing lever was **directed retrieval at plan
time** — the `build_page` `plan` step (page architecture: section order, the
states a real screen handles, edge cases) — not more prose or more entry.

**Does adding `build_page` to the poetry surface move the judged composition
score, and does it do so without regressing the other axes?**

## Design

- **Briefs:** the 12 page-scale briefs in `eval/pagescale.rb`
  (`POETRY_BENCH_SPEC=guided`). Composition is a page-scale property; these are
  the briefs where macrostructure is the graded axis.
- **Arms, per the benchmark's poetry-vs-raw structure. Two orthogonal knobs
  (the confound the first trial-1 exposed: `tools/list` advertises
  `build_page` to EVERY arm, so a control without it in the belt wasted turns
  on denied attempts and polluted the adoption count):**
  - `raw_tailwind` — the shared baseline (identical in both runs).
  - `poetry`, **control** — `POETRY_BENCH_BUILD_PAGE=1`: `build_page` is
    ALLOWED in the belt (advertised-and-allowed, so no denied attempts) but
    NOT routed. The agent falls to `compose` on its own (the smoke: available
    but unrouted → `compose`, `build_page` unused).
  - `poetry`, **treatment** — `POETRY_BENCH_GUIDED=1` (implies availability):
    the host AGENTS.md ROUTES page briefs to `build_page` first
    (`Benchmark#guided_routing`). **Routing is the sole treatment difference —
    the guided ENTRY, isolated from availability** — because the belt alone is
    inert (the smoke: build_page in the belt, unrouted, went unused; routed, it
    ran 4× the full workflow). Hermetic and guided-run-only; the shipped
    compose-first doctrine is untouched until a result justifies
    changing it. The raw belt is never touched.
- **The graded axis is the paired JUDGE:** hierarchy · composition · clarity ·
  brief_fit, forced choice, blind (README honesty rules). The mechanical gates
  run as usual (cross-arm, portable) but composition is a judged axis.

## Method upgrades (from the Braintrust Paper-MCP-vs-Figma-MCP run)

1. **Publish the ceiling first.** Author one hand-perfect poetry page per brief
   (`eval/results/<date>-ceiling/generated/<task>/poetry.html.erb`), score and
   judge it BEFORE any treatment claim, and report the ceiling. A treatment
   number is only legible against the known-perfect answer.
2. **Three trials per row.** Generation is nondeterministic (the claude CLI
   exposes no temperature control), so run generate → score → judge three times
   per arm under distinct `POETRY_BENCH_DATE`s and report the spread. **Variance
   is a finding, not noise to average away.**
3. **Linkable per-row traces.** Keep each unit's claude CLI transcript
   (tool-call sequence) alongside its verdict, so "did the treatment arm call
   `build_page`, and at which step did composition improve or not" is auditable
   per brief, not inferred from the aggregate.

## Pre-registered predictions (frozen before the run)

- **P1 — composition moves.** The treatment arm's composition win-rate over raw
  exceeds the control arm's by a margin that survives the 3-trial spread. (The
  /79 result was composition *unmoved*; P1 is the directional claim.)
- **P2 — the tool is actually used.** The treatment arm invokes `build_page` on
  ≥ 9 / 12 briefs (the tool-entry-adoption bar, 31/31, sets the
  expectation that a well-described page tool gets called).
- **P3 — no axis regresses.** Treatment does not lose to control on hierarchy,
  clarity, brief_fit, or any mechanical gate (guided planning must not cost the
  wins poetry already has).
- **The honest null is a result.** If composition is unmoved (P1 fails) with
  full adoption (P2 holds), that is the finding — the same shape as/79,
  and it says the lever is elsewhere. It gets reported, not buried.

## Running it (on-demand, real token cost, NEVER CI)

Per the eval cadence: judged runs are per-release / per-milestone, under an
explicit green-light. Three trials each of control and treatment. **The full
two-condition chain is too long for one background job (the first trial-1 was
SIGTERM'd mid-judge), so run each stage separately per condition** rather than
the chained `eval:benchmark:run`:

```
# control (build_page allowed, NOT routed), trial i of 3
env="POETRY_BENCH_SPEC=guided POETRY_BENCH_BUILD_PAGE=1 POETRY_BENCH_DATE=<date>-control-<i>"
$env bin/rake eval:benchmark:hosts eval:benchmark:generate
$env bin/rake eval:benchmark:score eval:benchmark:capture
$env bin/rake eval:benchmark:judge eval:benchmark:aggregate
# treatment (build_page routed), trial i of 3 — GUIDED=1 implies availability
env="POETRY_BENCH_SPEC=guided POETRY_BENCH_GUIDED=1 POETRY_BENCH_DATE=<date>-guided-<i>"
$env bin/rake eval:benchmark:hosts eval:benchmark:generate
$env bin/rake eval:benchmark:score eval:benchmark:capture
$env bin/rake eval:benchmark:judge eval:benchmark:aggregate
```

The manifest records `guided`, `build_page_available`, and the resolved
toolbelts, so a run is reproducible from its own artifacts. Each unit's tool
tally (stream-json trace) makes `build_page` adoption auditable per brief;
with the tool allowed in both arms, a recorded call is a real call, not a
denied attempt. Optionally re-validate a positive result on the reserved
`holdout` stratum (`POETRY_BENCH_SPEC=holdout`) to check it generalized.

## Doctrine

- **Report every run in the decision log, including the losses** (the holdout
  rule, applied here): an unreported guided run is a tuned eval.
- The pagescale briefs are not a `build_page` training set (the tool is new),
  so they are a fair first measure; the holdout is the generalization check.
- Never edit `build_page` citing a *this-eval* failure as the sole motivation
  without re-validating on the holdout — evidence of a fix must generalize.
