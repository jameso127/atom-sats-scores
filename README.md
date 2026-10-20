# Atom: KS2 SATs scaled scores

A dbt project on BigQuery that gives every pupil a KS2 SATs-style scaled score (80–120) in each
scored subject, recomputable as at any date. Design and rationale: `PLAN.md`; conventions: `CLAUDE.md`.

## Setup
Requires [uv](https://docs.astral.sh/uv/) and the gcloud CLI.

```sh
uv sync                                     # Python 3.12 + pinned dbt-core / dbt-bigquery (uv.lock)
gcloud auth application-default login       # OAuth for BigQuery
uv run dbt deps
uv run dbt debug                            # needs ~/.dbt/profiles.yml, below
uv run dbt build
uv run dbt build --vars '{as_at: "2025-09-01"}'   # point-in-time run
```

`~/.dbt/profiles.yml` (not committed):

```yaml
atom_ks2:
  target: dev
  outputs:
    dev:
      type: bigquery
      method: oauth
      project: atom-analytics-candidates
      dataset: james_oakley
      location: europe-west2
      threads: 4
      job_execution_timeout_seconds: 300
```

**Updating the conversion tables** (STA publishes each July):
`uv run python scripts/build_ks2_conversion_seed.py --expect maths=N,reading=N,gps=N`, then
`uv run dbt seed`. `--check` reports drift between the seed and GOV.UK without writing.

## Outputs
_TODO: `pupil_subject_sats_scores`, `fct_pupil_subject_score_history`; grain, keys, columns._

## Scope and subject decisions
_TODO_

## Assumptions
- Everyone, including KS1 pupils, is scored on the one KS2 80–120 scale; year group is a label
  (`latest_year_group`, `key_stage_at_score`). A KS1 / Year 3–4 score is an on-track measure, not
  current SATs attainment.

## Data quality log
_TODO: from `analyses/FINDINGS.md`._

## Verification
_TODO: re-run / full-refresh checksums, hand-checked pupils, as-at run._

## Limitations and next steps
_TODO_

## Predicting GCSE grades
_TODO_

## AI usage
Prompts, plans and session notes are in `ai/`.
