# Atom: KS2 SATs scaled scores

A dbt project on BigQuery that gives every pupil a SATs-style scaled score in Maths and English
(KS1 85–115, KS2 80–120, on the official STA tables for their key stage), plus % correct in every assessed subject, recomputable as at any date. The output is
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

**Updating the conversion tables** (STA publishes KS1 in June, KS2 in July):
`uv run python scripts/build_conversion_seed.py <ks1|ks2> <year>` fetches the tables from the
GOV.UK Content API, checks them, writes `seeds/scaled_scores/seed_scaled_scores_<ks>_<year>.csv`
and regenerates `models/staging/stg_scaled_score_conversion.sql` (a union of every table).
Then `uv run dbt build`.

## Outputs
All in `atom-analytics-candidates.james_oakley`.

```
de_raw.* ──► stg_* views ──┬──────────────────────────► trf_pupil_subject_daily (incremental)
                           └► trf_assessment_key_stage ──┘          │
STA KS1 + KS2 seeds ► stg_scaled_score_conversion                    ▼
   └► trf_percent_to_scaled_score (lookup) ──────► pupil_subject_year_scores ► pupil_subject_sats_scores
```

| model | layer | grain | built as |
|---|---|---|---|
| `pupil_subject_sats_scores` | ready | **pupil × subject** (the app table): the latest year group's score; key `(pupil_id, subject_name)` | table |
| `pupil_subject_year_scores` | ready | pupil × subject × year group; key `(pupil_id, subject_name, year_group)` | table |
| `trf_percent_to_scaled_score` | transform | key stage × conversion year × subject × whole percent (0–100) | table |
| `trf_assessment_key_stage` | transform | assessment: the key stage it's mainly sat by | table |
| `trf_pupil_subject_daily` | transform | pupil × subject × key stage × year group × day (in-scope responses only) | incremental, `insert_overwrite` of the last 3 days |
| `stg_*` | staging | the source tables (only the columns used); the conversion seeds unioned | views |

Columns of `pupil_subject_sats_scores`: `pupil_id`, `subject_name`, `key_stage` and `year_group`
(what the score is for), `scaled_score` (Maths and English only: KS1 85–115, KS2 80–120; null
otherwise),
`percent_correct`, `n_answered`, `n_correct`, `conversion_table_year`, `last_answered_date`.
A pupil has a row only for subjects they've answered something in; **no row = no score yet**.
A scaled score of 100 or more meets the expected standard. `pupil_subject_year_scores` has the
same columns for every year group, not just the latest.

## How a score is calculated
1. **Scope.** A response counts when its sitting exists and isn't deleted, its pupil isn't deleted,
   the sitting style is `fixed_question` or `non_adaptive` (adaptive tunes difficulty to the
   pupil, so % correct stops measuring ability; surveys have no right answers), and **the pupil's
   key stage at the sitting matches the assessment's**. Each assessment's key stage is the one
   most of its sittings are in (tie = KS2; `trf_assessment_key_stage`), so a KS1 pupil's go at a
   KS2 assessment isn't scored, nor a KS2 pupil's go at a KS1 one.
2. **Add up per year group.** For each pupil × subject × year group (of the sitting), add up every
   response up to the as-at date: `percent_correct = 100 × n_correct / n_answered`. A skipped
   question counts as answered and wrong, as on a real paper.
3. **Look up the scaled score** (Maths and English only) in `trf_percent_to_scaled_score`, on
   - the pupil's **key stage** at the sitting (KS1 = Years 1–2, KS2 = 3–6): KS1 uses the KS1
     tables (85–115), KS2 the KS2 tables (80–120);
   - the **academic year** (Sep–Aug) of the pupil's latest response in that year group: Sep 2025 –
     Aug 2026 uses the 2025 tables, which STA published in June / July 2025. Calendar year would
     need the 2026 tables from January 2026, months before they exist, and would silently change
     old scores when they arrived;
   - the subject;
   - `percent_correct` rounded down to a whole percent.
4. **The lookup** is built once from the official STA tables (KS1 and KS2, 2024–2026): for each
   percent, the equivalent raw mark on each test is `floor(percent × full marks / 100)` (marks are
   earned, so round down), converted with the official table. English averages its reading and
   GPS scores at both key stages (`seeds/seed_subject_to_test.csv`). Raw marks 0–2 have no
   official score and count as the bottom of the scale (KS1 85, KS2 80).
5. **The app table** keeps, for each pupil × subject, the latest year group's row.

Atom's assessments are shorter than real papers, which is why scoring goes through a percentage
rather than looking up a raw total. The percentage isn't mapped straight onto the scale because
the official curve isn't linear: 90% in KS2 Maths (99/110) scores 112 on the 2025 table, a
straight line gives 116.

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
- **Each key stage on its own scale.** KS1 pupils (Years 1–2) are scored on the official KS1
  tables (85–115), KS2 pupils on the KS2 tables (80–120), so `key_stage` must be shown alongside
  the score: a KS1 100 and a KS2 100 both mean "expected standard" but aren't the same score.
  KS1 tests have been optional since 2024, but STA still publishes their tables. A Year 3–4 score
  is still on the KS2 curve, so it's an "on track for KS2" measure, not SATs attainment.
- **Assessment key stage by majority.** An assessment's key stage is where most of its sittings
  are (tie = KS2, the harder content). Responses from pupils in the other key stage are dropped,
  so a KS1 pupil stretching to KS2 work, or a KS2 pupil revising KS1 work, doesn't distort their
  score. See `analyses/32_key_stage_mismatch.sql` for how many responses this removes.
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
Run on 2026-10-22, after adding the KS1 tables and the key-stage match.

- **`dbt build --full-refresh`:** 45 tests pass; 1 expected warning (the 1,433 responses whose
  sitting is missing).
- **Re-runnable:** row counts and an order-independent checksum of each model
  (`analyses/29_output_checksums.sql`) are identical after the full refresh and an incremental
  run: 63,707 responses → 1,399 daily rows → 405 year scores → 399 app rows (pupil × subject).
- **Key-stage match** (`analyses/32_key_stage_mismatch.sql`): 566 responses are dropped, 498 from
  KS1 pupils on mainly-KS2 assessments (8 pupils) and 68 from KS2 pupils on mainly-KS1 assessments
  (3 pupils). No assessment was tied.
- **Hand check** (`analyses/30_hand_check.sql`): the current score is recomputed straight from
  `de_raw` (including the key-stage match) for the most active KS1 and KS2 pupil in each subject;
  all four match the model.

  | subject | key stage | year | answered | correct | % | working (2025 tables) | score |
  |---|---|---|---|---|---|---|---|
  | English | KS1 | 2 | 181 | 157 | 86.7% | gps raw 34 → 109; reading raw 34 → 107 | 108 |
  | English | KS2 | 5 | 322 | 144 | 44.7% | gps raw 30 → 98; reading raw 22 → 96 | 97 |
  | Maths | KS1 | 2 | 144 | 93 | 64.6% | maths raw 38 → 101 | 101 |
  | Maths | KS2 | 5 | 189 | 97 | 51.3% | maths raw 56 → 99 | 99 |
- **As-at run:** checked on 2026-10-21 (`as_at: 2026-03-01` adds up only earlier responses, and a
  rebuild without `as_at` restores the current tables); the mechanism hasn't changed since.
- **Distribution** (`analyses/31_score_distribution.sql`, app table):

  | subject | key stage | pupils | scaled score quartiles | meet expected (≥ 100) | avg % correct |
  |---|---|---|---|---|---|
  | English | KS1 | 48 | 85 / 96 / 99 / 102 / 115 | 50% | 57.9 |
  | English | KS2 | 106 | 87 / 98 / 101 / 105 / 120 | 65% | 57.8 |
  | Maths | KS1 | 48 | 92 / 96 / 98 / 100 / 110 | 40% | 55.6 |
  | Maths | KS2 | 104 | 80 / 97 / 101 / 105 / 114 | 60% | 58.5 |
  | Screeners | KS2 | 82 | — | — | 52.4 |
  | Verbal Reasoning | KS2 | 8 | — | — | 46.3 |
  | Non-Verbal Reasoning | KS2 | 3 | — | — | 63.9 |

  KS1 pupils meet the expected standard less often on the KS1 tables than they did on the KS2
  curve, because KS1 pupils' similar % correct sits lower on the KS1 curve.

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
- Topic names to split English into reading and GPS; 0.1% lookup steps;
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
