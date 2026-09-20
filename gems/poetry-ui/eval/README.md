# The eval harness

The empirical backbone: poetry's thesis — *an
LLM operating inside a constrained, legible UI system produces better UI than
one generating raw markup* — is a falsifiable claim, and this directory is the
experiment that tests it. Two halves:

- **Mechanical** (deterministic, token-free, in CI): frozen task arms scored
  by cross-arm gates. `rake eval:scorecard`, guarded by `rake eval:verify`.
- **Judged** (LLM, on-demand, never in CI): screenshots of both arms compared
  by a paired judge. `rake eval:capture` + `rake eval:judge`.

## Layout

- `arms/<task>/{poetry,raw_tailwind}.html.erb` — 31 frozen task pairs, one per
  component family. Raw arms are FROZEN representative generations, realistic
  and never strawmen, authored WITH the typical failure modes (the A/B tell).
- `captures/<task>/<arm>.png` — the judge's evidence: every arm rendered in
  the dummy through the browser rig (light, 1024×768, reduced motion), with
  one representative reveal click on overlay-family tasks (identical on both
  arms — an arm whose trigger does nothing captures that truth).
- `results/<date>/judge-verdicts.json` — committed FROZEN-arm judge runs
  (`judge-v1`; the calibration lives here and only here).
- `results/2026-07-07/` is the FROZEN pre-registered benchmark run — never
  rewritten; `results/2026-07-08/` is its remediation run (subset
  regeneration + theme variants) layered beside it.
- `results/<date>/` benchmark artifacts: `generated/<task>/<arm>.html.erb`
  (the agent-written arms), `generation-manifest.json`, `generated-scorecard.json`,
  `captures/`, `benchmark-verdicts.json`, `results.json` (`results-v1`).
- `runner.rb` — the mechanical scorer (arms_root swaps the corpus).
  `judge.rb` — the paired judge. `benchmark.rb` — the generated-arm
  benchmark driver.

## The honesty rules

1. **Scorer portability:** cross-arm gates run identically on every
   arm and are the only comparable numbers; `poetry_only` gates cannot
   structurally fail a non-poetry artifact and are reported as diagnostics,
   never as comparisons.
2. **The judge is blind:** it sees the brief, both screenshots, and both
   cross-arm ledgers — never the poetry_only diagnostics, never which arm is
   which. Captures stage to position-named tmp files outside the repo (the
   repo path itself says "poetry"); `Judge.assert_blind!` raises on any leak.
3. **The judge is paired, never absolute** (the calibration finding: judges
   are near chance on absolute design scores, usable on paired comparison
   with concrete axes): forced choice per axis — hierarchy · composition ·
   clarity · brief_fit — plus overall, with rationale.
4. **Position bias is measured, not assumed away:** 3 votes per presentation
   order (A/B, then B/A; the claude CLI exposes no temperature control, so
   the swap discipline carries the determinism load). A verdict that only
   ever appears in one order is discarded as position-biased; the majority of
   surviving votes decides; no survivor = `inconclusive`, an honest verdict
   class that is reported, not hidden.

## Commands

| Command | What | Needs |
|---|---|---|
| `rake eval:verify` | Regression net: poetry arms fully green, every raw arm still fails ≥1 cross-arm gate. **In the default gate / CI.** | nothing |
| `rake eval:scorecard` | Full mechanical scorecard → `tmp/eval-scorecard.json`, folding the latest committed judge verdicts as a read-only `judged` section | nothing |
| `rake eval:capture` | Screenshot all 62 arms → `eval/captures/` | Chrome |
| `rake eval:judge` | Paired judge over the frozen arms → `eval/results/<date>/judge-verdicts.json` | Chrome captures + the `claude` CLI |

`eval:judge` env: `POETRY_JUDGE_TASKS=a,b` (subset), `POETRY_JUDGE_MODEL`
(default `claude-sonnet-5`), `POETRY_JUDGE_CONCURRENCY` (default 4),
`POETRY_JUDGE_DATE` (results dir override).

## Calibration — the frozen arms have known intended winners

The raw arms were authored WITH failure modes, so the intended winner is the
poetry arm on every task: a frozen-arm judge run is the harness's own
calibration set, and its agreement rate is reported in the verdicts file
(`calibration` key) **before any thesis claim rests on the judge**.
Inconclusives count against agreement in the headline rate (`agreement_rate`)
and are excluded in `agreement_rate_decided`.

## Cadence

- **Mechanical** (`eval:verify`): every default-gate run, every CI push.
- **Judged** (`eval:capture` + `eval:judge`): **on demand — per release and
  per major milestone. Never in CI** (real cost, nondeterministic residue
  even with the swap discipline). Re-record captures first when components
  or themes changed.

## The generated-arm benchmark (the thesis test)

Frozen arms measure the *system's floor*; the thesis claim is about **agent
output**. Protocol pre-registered before the run: per brief, generation agent A works in a
fixture host WITH poetry (the installed surface: the AGENTS.md section from
`rails g poetry:agents`, llms.txt/llms-full.txt materialized from the live
registry, `bin/check` wrapping `poetry:check`), agent B in a raw-Tailwind
twin — same model, same turn budget, ONE identical prompt (the treatment
lives entirely in host files). Both outputs run the full mechanical array,
then this judge. Stages (each idempotent/resumable; `eval:benchmark:run`
chains them):

| Command | What |
|---|---|
| `rake eval:benchmark:hosts` | Build the twin fixture hosts (token-free) |
| `rake eval:benchmark:generate` | claude CLI agents write every arm → `generated/` + manifest |
| `rake eval:benchmark:score` | Mechanical gates on generated arms → `generated-scorecard.json` |
| `rake eval:benchmark:capture` | Screenshots, stylesheet compiled WITH the generated arms as a Tailwind source (no purge bias) |
| `rake eval:benchmark:judge` | The paired judge → `benchmark-verdicts.json` (never `judge-verdicts.json`) |
| `rake eval:benchmark:capture_themed` | Theme variant: poetry arms recaptured under `POETRY_BENCH_THEME` (default vega), raw PNGs reused byte-for-byte from the source run |
| `rake eval:benchmark:aggregate` | Fold into `results.json` (`results-v1`) with the pre-registered prediction checks |

Env: `POETRY_BENCH_DATE`, `POETRY_BENCH_MODEL`, `POETRY_BENCH_MAX_TURNS`,
`POETRY_BENCH_HOSTS`, `POETRY_BENCH_TASKS`, `POETRY_BENCH_CONCURRENCY`,
`POETRY_BENCH_FORCE=1`, plus the `POETRY_JUDGE_*` family for the judge leg.
Variant runs (remediation): `POETRY_BENCH_ARMS` regenerates only the
listed arms (the control stays the pre-registered sample);
`POETRY_BENCH_SOURCE` points judge/capture_themed at another run's
`generated/` (+ its `captures/` for reused raw PNGs);
`POETRY_BENCH_CAPTURES_DIR` and `POETRY_BENCH_VERDICTS` name a variant's
captures dir and verdicts file so the run's own `benchmark-verdicts.json`
stays frozen. `results-remediation.json` (schema `results-remediation-v1`)
folds the subset re-run + theme variants; the pre-registered `results.json`
is never rewritten.

Fairness invariants (runtime-enforced where possible): generation is
hermetic — agents run via the claude CLI cwd'd into tmp twin hosts outside
this repo, and `Benchmark.assert_hermetic!` raises if host B's tree or the
prompt ever contains the house name; the generation prompt takes no arm
parameter; the no-`<script>` rule is symmetric (native HTML capabilities
allowed on both arms); the capture stylesheet compiles the generated arms
as an extra `@source` so arbitrary raw utilities render with full
fidelity. The run spends real generation + judging tokens: only under its
own green-light, on-demand cadence, never CI.

## Degradation mode

The benchmark measures ONE-SHOT output; degradation mode measures whether
convention adherence survives a working session: follow-up edits, filler
questions polluting the context, and one temptation to abandon the app's
conventions. Driver: `eval/degradation.rb` (protocol = its `SEQUENCE`
constant, pre-registered: brief → probe p0 → 3 fillers → edit 1 → p1 →
distractor → filler → edit 2 → p2). Multi-turn rides `claude -p --resume`
session chains; the probe dirs are benchmark-run shaped so score/capture/
judge are the UNCHANGED `eval:benchmark:*` stages run per probe (p1 is
mechanical-only). `rake eval:degradation:run` chains everything; results
land at `eval/results/<date>-degradation/` (`degradation-v1`). Budget
exhaustion on a follow-up is recorded data, never a unit error — the next
probe scores whatever state the artifact reached.

## The holdout stratum

Eight briefs in `eval/holdout.rb`, RESERVED for validating agent-surface
changes (skills, AGENTS.md, llms text, MCP descriptions) — the standing 31
get tuned against over time; these must not be. Doctrine (in the file, and
binding): never cite a holdout failure as motivation for an edit; run only
when a surface change claims improvement (`POETRY_BENCH_SPEC=holdout`
through the full benchmark machinery, before/after); report every run in
the decision log including losses. An unreported holdout run is a tuned
holdout.

## The guided-workflow eval

`POETRY_BENCH_SPEC=guided` runs the 12 page-scale (`pagescale`) briefs as a
control-vs-treatment pair: the treatment (`POETRY_BENCH_GUIDED=1`) adds
`mcp__poetry__build_page` to the poetry belt, the control is the standing
belt, the raw arm is untouched. The graded question — does the guided
workflow move the judged **composition** score where the earlier surface levers did not — plus
the full protocol (known-perfect ceiling, three trials, linkable traces),
the pre-registered predictions, and the run commands live in
`eval/guided.md`. On-demand, real token cost, never CI; report every run in
the decision log including losses.
