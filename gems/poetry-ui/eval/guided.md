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
- **Arms, per the benchmark's poetry-vs-raw structure:**
  - `raw_tailwind` — the shared baseline (identical in both runs).
  - `poetry`, **control** — the standing poetry belt (`compose`, `check`,
    `describe_*`, `list_*`), no `build_page`.
  - `poetry`, **treatment** — `POETRY_BENCH_GUIDED=1` adds
    `mcp__poetry__build_page` to the poetry belt AND routes page briefs to it
    in the host's AGENTS.md (`Benchmark#guided_routing`). The belt alone is not
    the treatment: a smoke proved availability does not drive adoption — the
    agent used `compose` (whose description says "CALL THIS FIRST for every
    brief"), never `build_page`. So the treatment is the guided **entry**, not
    the tool's mere presence; that is the hypothesis. The routing is hermetic
    and guided-run-only — the shipped compose-first doctrine is
    untouched until an eval result justifies changing it. **The raw belt is
    never touched — the asymmetry is the treatment** (`Benchmark.toolbelt`).
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
explicit green-light. Three trials each of control and treatment:

```
# control (standing belt), trial i of 3
POETRY_BENCH_SPEC=guided POETRY_BENCH_DATE=<date>-control-<i> bin/rake eval:benchmark:run
# treatment (belt + build_page), trial i of 3
POETRY_BENCH_SPEC=guided POETRY_BENCH_GUIDED=1 POETRY_BENCH_DATE=<date>-guided-<i> bin/rake eval:benchmark:run
```

`eval:benchmark:run` chains hosts → generate → score → capture → judge →
aggregate (README). The manifest records `guided` and the resolved toolbelts,
so a run is reproducible from its own artifacts. Optionally re-validate a
positive result on the reserved `holdout` stratum
(`POETRY_BENCH_SPEC=holdout`, its own doctrine) to check it generalized.

## Doctrine

- **Report every run in the decision log, including the losses** (the holdout
  rule, applied here): an unreported guided run is a tuned eval.
- The pagescale briefs are not a `build_page` training set (the tool is new),
  so they are a fair first measure; the holdout is the generalization check.
- Never edit `build_page` citing a *this-eval* failure as the sole motivation
  without re-validating on the holdout — evidence of a fix must generalize.
