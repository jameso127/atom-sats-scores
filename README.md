# Atom: KS2 SATs scaled scores

A dbt project on BigQuery that gives every pupil a KS2 SATs-style scaled score (80–120) in Maths
and English, plus % correct in every assessed subject, recomputable as at any date. The output is
a flat, long table (one row per pupil × subject), ready for the app database.

Supporting material: `analyses/FINDINGS.md` (profiling and data quality evidence), `PLAN.md`
(design), `CLAUDE.md` (conventions), `ai/` (AI usage).

## Setup
Requires [uv](https://docs.astral.sh/uv/) and the gcloud CLI.

```sh
uv sync                                     # Python 3.12 + pinned dbt-core 1.12 / dbt-bigquery 1.12 (uv.lock)
gcloud auth application-default login       # OAuth for BigQuery
uv run dbt deps
uv run dbt debug                            # needs ~/.dbt/profiles.yml, below
uv run dbt build
uv run dbt build --vars '{as_at: "2026-03-01"}'   # point-in-time run
uv run sqlfluff lint models tests analyses        # SQL style (fix: sqlfluff fix ...)
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
`uv run python scripts/build_ks2_conversion_seed.py <year>` fetches the year's tables from the
GOV.UK Content API, checks them, writes `seeds/ks2_scaled_scores/seed_ks2_scaled_scores_<year>.csv`
and regenerates `models/staging/stg_ks2_scaled_score_conversion.sql` (a union of every year).
Then `uv run dbt build`.

## Outputs
All in `atom-analytics-candidates.james_oakley`.

```
de_raw.* ──► stg_* views ──► trf_pupil_subject_daily (incremental)
                                                         │
STA seeds ► stg_ks2_scaled_score_conversion              ▼
   └► trf_percent_to_scaled_score (lookup) ──────► pupil_subject_year_scores ► pupil_subject_sats_scores
```

| model | layer | grain | built as |
|---|---|---|---|
| `pupil_subject_sats_scores` | ready | **pupil × subject** (the app table): the latest year group's score; key `(pupil_id, subject_name)` | table |
| `pupil_subject_year_scores` | ready | pupil × subject × year group; key `(pupil_id, subject_name, year_group)` | table |
| `trf_percent_to_scaled_score` | transform | conversion year × subject × whole percent (0–100) | table |
| `trf_pupil_subject_daily` | transform | pupil × subject × year group × day (in-scope responses only) | incremental, `insert_overwrite` of the last 3 days |
| `stg_*` | staging | the source tables (only the columns used); the conversion seeds unioned | views |

Columns of `pupil_subject_sats_scores`: `pupil_id`, `subject_name`, `year_group` (the year group
the score is for), `scaled_score` (80–120, Maths and English only, null otherwise),
`percent_correct`, `n_answered`, `n_correct`, `conversion_table_year`, `last_answered_date`.
A pupil has a row only for subjects they've answered something in; **no row = no score yet**.
A scaled score of 100 or more meets the expected standard. `pupil_subject_year_scores` has the
same columns for every year group, not just the latest.

## How a score is calculated
1. **Scope.** A response counts when its sitting exists and isn't deleted, its pupil isn't deleted,
   and the sitting style is `fixed_question` or `non_adaptive` (adaptive tunes difficulty to the
   pupil, so % correct stops measuring ability; surveys have no right answers).
2. **Add up per year group.** For each pupil × subject × year group (of the sitting), add up every
   response up to the as-at date: `percent_correct = 100 × n_correct / n_answered`. A skipped
   question counts as answered and wrong, as on a real paper.
3. **Look up the scaled score** (Maths and English only) in `trf_percent_to_scaled_score`, on
   - the **academic year** (Sep–Aug) of the pupil's latest response in that year group: Sep 2025 –
     Aug 2026 uses the 2025 table, which STA published in July 2025. Calendar year would need the
     2026 table from January 2026, months before it exists, and would silently change old scores
     when it arrived;
   - the subject;
   - `percent_correct` rounded down to a whole percent.
4. **The lookup** is built once from the official STA tables (2024, 2025, 2026): for each percent,
   the equivalent raw mark on each KS2 test is `floor(percent × full marks / 100)` (marks are
   earned, so round down), converted with the official table. English averages its reading and
   GPS scores (`seeds/seed_subject_to_ks2_test.csv`). Raw marks 0–2 have no official score and
   count as 80.
5. **The app table** keeps, for each pupil × subject, the latest year group's row.

Atom's assessments are shorter than real papers, which is why scoring goes through a percentage
rather than looking up a raw total. The percentage isn't mapped straight onto 80–120 because the
official curve isn't linear: 90% in Maths (99/110) scores 112 on the 2025 table, a straight
line gives 116.

## Scope and subject decisions
| subject | treatment | why |
|---|---|---|
| Maths | scaled score + % | direct KS2 test |
| English | scaled score (½ reading + ½ GPS) + % | Atom's English covers both; topic names aren't available to split it |
| Screeners | % only | diagnostic checks, not a curriculum subject; no KS2 test (17% of responses) |
| Verbal / Non-Verbal Reasoning | % only | 11+ aptitude, not KS2 curriculum |
| **Science** | **not included (for now)** | 335 questions in the hierarchy but **no responses**; not a SATs test. Rows appear automatically once responses exist (% correct); a seed row would give it a scaled score |
| Wellbeing | not included | surveys only, no right answers |

## Assumptions and design trade-offs
- **One KS2 scale for everyone.** KS1 pupils are scored on the KS2 80–120 curve, so a KS1 or
  Year 3–4 score is "on track for KS2 on age-appropriate work", not current SATs attainment;
  `year_group` lets the app label it. Real KS1 tests have their own 85–115 scale (next step).
- **Each year group is scored separately**, so a Year 5 score isn't diluted by Year 2 work. The
  flip side: early in a new school year the current score rests on few responses (in Sep 2026, 26
  pupils had only that month's work). `n_answered` is in the output so the app can judge it.
- **Whole-percent lookup.** Simple to read and join, but coarser than raw marks on Maths (1% ≈ 1.1
  marks), so a score can be about 1 point lower near a boundary. For example the Year 2 Maths
  pupil in the hand check gets raw 70 → 102 here, against raw 71 → 103 from an exact raw-mark
  calculation. 0.1% steps would be a one-number change in two places.
- **Long app table** (pupil × subject) rather than wide (a column per subject): a new subject is
  new rows, not a schema change in the app database; queries like "all Maths scores" or "any
  subject below 100" are a simple `WHERE`; the key `(pupil_id, subject_name)` indexes naturally.
  The app pivots for a per-pupil dashboard, or a wide view can sit on top. Pupils with no
  responses have no rows; the app joins from its own pupils table.
- **Point-in-time is a rebuild,** not a history table: `--vars '{as_at: ...}'` adds up only
  responses on or before that date. While an as-at build is loaded, the ready tables show that
  date; rebuild without `as_at` to return to current. (An earlier version kept a day-by-day
  `valid_from` / `valid_to` history; it was dropped for simplicity.)
- **Re-runnable:** no `current_date()`; the one `row_number()` is ordered deterministically
  (latest date, then highest year group); a full refresh and an incremental run give identical output.

## Data quality log
Full log with numbers: `analyses/FINDINGS.md`. The issues that affect scores:

- **Responses whose sitting doesn't exist.** 1,433 responses (2.2%) reference 56 `session_id`s
  missing from `assessment_sittings` (1,196 of them English / Maths, from 40 pupil-subject
  combinations). **Excluded:** without the sitting there's no style, deleted flag or year group,
  so the scope rules can't be applied. The pupils exist and have other valid sittings, so these
  could be scored with an assumed style (next step). A `relationships` test warns on them.
- **Repeated question rows within a sitting (identified, not fixed).** 4,493 rows (7.1%) repeat
  a pupil × sitting × question with the same timestamp and question number, sometimes with
  conflicting outcomes. The evidence points to duplicate events rather than multi-mark questions:
  `total_questions` matches the distinct question count in 709 of 749 affected sittings, and
  English / Maths questions repeat in some sittings but not others. **All rows are counted** (each
  as one mark), since there's no way to tell which duplicate is real. This is neutral on average:
  collapsing to the mean gives the same % correct, while "correct if any row is correct" would add
  ≈ 0.8 points. Worth raising with the platform team.
- **`responses.session_type` is always `MOCK_TEST`**, disagreeing with every sitting, so it isn't used.
- **No soft-deleted pupils or sittings** today; the filters stay as a production guard.
- **Science has questions but no responses**; Screeners have right / wrong answers and are never
  mixed with other subjects (the planned reasons for excluding them didn't hold; they're excluded
  from scaled scores because there's no KS2 test, not because of data quality).

## Verification
Run on 2026-10-21.

- **`dbt build --full-refresh`:** 59 tests pass; 1 expected warning (the 1,433 responses whose
  sitting is missing).
- **Re-runnable:** row counts and an order-independent checksum of each model
  (`analyses/29_output_checksums.sql`) are identical after the full refresh and an incremental
  run: 63,707 responses → 1,415 daily rows → 407 year scores → 399 app rows (pupil × subject).
- **Hand check** (`analyses/30_hand_check.sql`): the current score is recomputed straight from
  `de_raw` for the most active KS1 and KS2 pupil in each subject; all four match the model.

  | subject | year | answered | correct | % | working (2025 table) | score |
  |---|---|---|---|---|---|---|
  | English | 2 | 181 | 157 | 86.7% | gps raw 60 → 115; reading raw 43 → 113 | 114 |
  | English | 5 | 322 | 144 | 44.7% | gps raw 30 → 98; reading raw 22 → 96 | 97 |
  | Maths | 2 | 144 | 93 | 64.6% | maths raw 70 → 102 | 102 |
  | Maths | 5 | 189 | 97 | 51.3% | maths raw 56 → 99 | 99 |
- **As-at run** (`as_at: 2026-03-01`): 134 pupils have English and Maths scores (no Screeners or
  reasoning sittings by then); rebuilding without `as_at` restores the original checksum.
- **Distribution** (`analyses/31_score_distribution.sql`, app table):

  | subject | pupils | scaled score quartiles | meet expected (≥ 100) | avg % correct |
  |---|---|---|---|---|
  | English | 154 | 85 / 98 / 102 / 105 / 120 | 65% | 57.8 |
  | Maths | 152 | 80 / 97 / 101 / 104 / 114 | 57% | 57.6 |
  | Screeners | 82 | — | — | 52.4 |
  | Verbal Reasoning | 8 | — | — | 46.3 |
  | Non-Verbal Reasoning | 3 | — | — | 63.9 |

## Limitations and next steps
- Score the 1,196 English / Maths responses whose sitting is missing, with an assumed style.
- Confirm with the platform team whether repeated question rows are duplicates.
- **Incremental and deletes:** a pupil or sitting soft-deleted *after* its responses were loaded
  stays in `trf_pupil_subject_daily` until its day is recomputed (3-day lookback) or a
  `--full-refresh`. A production version would full-refresh on a schedule.
- **Late data older than the lookback** is missed until a full refresh; there's no load timestamp
  to find it by. For the same reason there's no bitemporal "what did the app show on date X".
- **The raw `responses` table isn't partitioned,** so each incremental run still scans it in full
  (~10 MB now). Partitioning it on `answered_at` would let the staging view read only recent days.
  Staging is a view rather than an incremental copy because, with the raw table unpartitioned,
  a copy would scan the same data and add a second table to keep in step.
- `course_hierarchy` has no validity dates: snapshot it from now on.
- KS1's own 85–115 scale; topic names to split English into reading and GPS; 0.1% lookup steps;
  recency weighting within a year group; IRT difficulty calibration (would let adaptive sittings be
  scored, and Atom's questions aren't SATs questions).

## Predicting GCSE grades
**Target and features.** The target would be each pupil's GCSE grade (9–1) per subject. Features
would start from this model's outputs: scaled scores per year group and their trajectory over
time, % correct in the non-SATs subjects, and engagement (volume, consistency, time taken, skip
rate). Topic-level strengths would add detail once topic names are available, and Verbal /
Non-Verbal Reasoning are useful aptitude signals here even though they aren't SATs subjects.
School context could help but needs care for fairness, since it can encode deprivation rather than
ability.

**Data needed.** The essential ingredient is **linked outcomes**: real GCSE results for past
platform users. That means either five or more years of history (a Year 6 pupil sits GCSEs five
years later) or a link to the National Pupil Database. The DfE's published KS2 → KS4 transition
matrices are the baseline any model would need to beat, and could be used as a prior before Atom
has its own outcomes.

**Assumptions and output.** It would assume our scaled scores mean the same thing over time
(stable tables, comparable questions), that past cohorts resemble future ones, and that the KS2 →
KS4 relationship holds for platform users, who may not be representative. Given the five-year gap
and how much happens in secondary school, the prediction should be reported as a **grade
distribution** (for example "60% chance of grade 6 or above"), not a single grade, and refreshed as
new evidence arrives.

## AI usage
This project was built with Claude Code. `ai/planning_log.md` records each decision and change of
direction (dated, with the reason), `PLAN.md` and `CLAUDE.md` are the working plan and the
conventions the AI followed, and `ai/sources/` holds the GOV.UK pages the conversion tables came
from. Every AI-written query and model was checked against the data (`analyses/`), and the
scoring was hand-checked from raw data.
