# The eval harness

The empirical backbone (completed by): poetry's thesis — *an
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
- `results/<date>/judge-verdicts.json` — committed judge runs (`judge-v1`).
- `runner.rb` — the mechanical scorer. `judge.rb` — the paired judge.

## The honesty rules

1. **Scorer portability:** cross-arm gates run identically on every
   arm and are the only comparable numbers; `poetry_only` gates cannot
   structurally fail a non-poetry artifact and are reported as diagnostics,
   never as comparisons.
2. **The judge is blind:** it sees the brief, both screenshots, and both
   cross-arm ledgers — never the poetry_only diagnostics, never which arm is
   which. Captures stage to position-named tmp files outside the repo (the
   repo path itself says "poetry"); `Judge.assert_blind!` raises on any leak.
3. **The judge is paired, never absolute** (the Design Crit finding: judges
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

## The generated-arm benchmark (W2 — the thesis test)

Frozen arms measure the *system's floor*; the thesis claim is about **agent
output**. The protocol is pre-registered in the vault plan note
("Components Library - N15 Judged Eval Plan"): per brief, agent A works in a
fixture host WITH poetry (gems + llms.txt + AGENTS.md + `poetry check`),
agent B in a twin host with raw Tailwind, same model, same turn budget;
both outputs run the full mechanical array, then this judge. Pre-registered
predictions live in that note. The run spends real generation + judging
tokens, so it happens only under its own green-light, and its artifacts
(generated sources, captures, verdicts, scorecard) are committed under
`results/<date>/`, schema `results-v1`.
