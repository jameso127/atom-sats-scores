# CLAUDE.md

Context for AI assistants (Claude Code etc.) working in this repo. Read this first, then `PLAN.md`.

## What this project is
A dbt project on BigQuery that converts mock pupil activity data into a KS2 SATs-style scaled score
(80–120) for every pupil in every scored subject, recomputable at any point in time. It is a take-home task
for Atom; **the reasoning matters more than the result**, so every non-obvious decision must be written
down (README "Assumptions" / "Data quality" sections, or inline SQL comments).

**Scale: everyone is scored on the one KS2 80–120 scale, including KS1 pupils (Years 1–2).** The
brief defines the scale as 80–120, which is the KS2 scale, and one curve keeps the output simple.
Year group is carried as a label (`latest_year_group`, `key_stage_at_score`) so the app can show a
KS1 or Year 3–4 score as "on track for KS2" rather than as a SATs result. Document this in the README.

## Stack
- **dbt Core 1.12.6** with **dbt-bigquery 1.12.1**, Python 3.12, managed by **uv**
  (`pyproject.toml` + `uv.lock`). Run everything through uv: `uv sync`, `uv run dbt ...`,
  `uv run python scripts/...`. Add Python dependencies with `uv add`, never pip.
- **BigQuery project:** `atom-analytics-candidates`
- **Source dataset (read only):** `raw_de`. Never write to it.
- **Target dataset (all models, seeds, snapshots):** `james_oakley`
- **Location:** `europe-west2`. Every query and the profile must use it.
- **Packages:** `dbt_utils` (add `dbt_expectations` only if needed).
- **Auth:** OAuth via gcloud, with `profiles.yml` in `~/.dbt/`. Never commit credentials.
- **Point-in-time runs:** `dbt build --vars '{as_at: "YYYY-MM-DD"}'`.
- **Cost:** `--dry_run` any ad-hoc query on `responses` before running it.

**Dataset naming:** dbt's default schema naming would create `james_oakley_staging` and similar. Add a
`generate_schema_name` macro so everything lands in `james_oakley`, since that's the dataset reviewers
were told to look at. Separate layers with model-name prefixes (`stg_`, `int_`, `fct_`) instead.

## Source tables (`atom-analytics-candidates.raw_de`)
Schemas are from `bq show --schema`. All fields are NULLABLE, so assume nothing is guaranteed
non-null until profiled.

### `responses`: one row per question a pupil answered. Expected to grow by more than 100m rows.
| column | type | notes |
|---|---|---|
| response_id | STRING | assumed PK; test uniqueness |
| pupil_id | STRING | FK → pupils |
| session_id | STRING | FK → assessment_sittings.session_id |
| session_type | STRING | denormalised copy of the sitting's session_type; check it agrees |
| question_id | STRING | FK → course_hierarchy |
| is_correct | BOOLEAN | correctness is binary, so there is no partial credit |
| is_no_attempt | BOOLEAN | the pupil skipped the question; check what is_correct is when true |
| seconds_taken | INTEGER | check for negatives and extreme outliers |
| question_number | INTEGER | position within the sitting |
| answered_at | TIMESTAMP | **event time for point-in-time**; partition key downstream |

### `assessment_sittings`: one row per assessment a pupil sat
| column | type | notes |
|---|---|---|
| session_id | STRING | assumed PK (this is the "sitting" id) |
| pupil_id | STRING | FK → pupils; check it agrees with responses.pupil_id |
| assessment_id | STRING | the assessment template; there is no assessments table |
| session_type | STRING | profile the distinct values |
| style | STRING | `fixed_question`, `non_adaptive`, `adaptive`, `survey`. Only the first two are scored |
| year_group_at_sitting | INTEGER | a label only, not a filter; see "Scope rules" |
| total_questions | INTEGER | compare with the count of responses in the session |
| is_complete | BOOLEAN | |
| is_deleted | BOOLEAN | soft delete |
| started_at / finished_at | TIMESTAMP | check that responses fall inside the window and finished ≥ started |

### `pupils`: one row per pupil
| column | type | notes |
|---|---|---|
| pupil_id | STRING | PK |
| is_deleted | BOOLEAN | soft delete; deleted pupils and their responses are excluded |

There are no demographics, school or created-at fields. "Every pupil" means every non-deleted pupil.

### `course_hierarchy`: one row per question
| column | type | notes |
|---|---|---|
| question_id | STRING | assumed PK; test that no question maps to two subjects |
| atom_id | STRING | a level between question and subtopic (question → atom → subtopic → topic → subject) |
| subtopic_id / topic_id | STRING | no names available, only IDs |
| subject_id / subject_name | STRING | map to KS2 tests via `seed_subject_to_ks2_test` |

Subjects present: Maths, English, Science, Verbal Reasoning, Non-Verbal Reasoning, Wellbeing,
Screeners. English has 5 topics (IDs only).

**Things the schemas tell us:**
- **No load timestamp anywhere.** Point-in-time is on `answered_at` (event time) only. The
  bitemporal question of "what would the app have shown on date X" can't be answered from this
  data; note it in the README as a limitation.
- **`course_hierarchy` has no validity dates.** Treat it as current-state. A dbt snapshot from
  now on would capture future re-parenting, but history before that is unrecoverable.
- **Soft deletes on two tables.** Filter `is_deleted` in staging, or carry it through and filter
  in marts; decide once and document it.

## Project layout and conventions
```
models/
  staging/       stg_<source_table>.sql        views; rename, cast, light cleaning only; 1:1 with source
  intermediate/  int_<description>.sql         joins/aggregations; incremental where large
  marts/         fct_* / <entity>_* .sql       final outputs; tables
seeds/           seed_*.csv                    STA conversion tables, subject mapping (+ _seeds.yml)
tests/           assert_*.sql                  singular tests (seed weights, completeness, monotonic)
snapshots/       snap_*.sql                    (next step) course_hierarchy history
scripts/         build_ks2_conversion_seed.py  fetches STA tables from the GOV.UK Content API into the conversion seed
macros/          reusable SQL (e.g. point-in-time filter, generate_schema_name)
analyses/        profiling / exploration queries (kept for the submission)
ai/              prompts, planning notes, AI session summaries; ai/sources/ = saved GOV.UK pages
```
- Every model has a `.yml` entry with a description, grain stated in words, and tests on its key.
- snake_case everything; IDs end `_id`; booleans start `is_` / `has_` / `meets_`; dates end `_date`,
  timestamps end `_at`.
- Lowercase SQL keywords, CTEs (`with ... as`) not subqueries, one CTE per logical step,
  final `select * from final`.
- Reference only via `{{ ref() }}` / `{{ source() }}`, never hard-coded table names.
  Sources are declared in `models/staging/_sources.yml` (source name `raw_de`).

## Non-negotiable design rules
1. **Re-runnable / deterministic.** No `current_timestamp()`, `current_date()` or `rand()` in business
   logic. "Now" comes from `var('as_at')`. Every `row_number()` has a fully deterministic `order by`
   (e.g. `answered_at, response_id`). Full-refresh and incremental runs must give identical output.
2. **Point-in-time.** Scores are derived only from responses with `answered_at` ≤ the as-at date.
   History lives in `fct_pupil_subject_score_history` with `valid_from` / `valid_to`; use the
   point-in-time macro rather than re-writing the filter.
3. **Scale.** Never full-scan `responses` downstream of the first incremental model. Partition large
   models by `date(answered_at)`, cluster by `pupil_id`, `subject_name`. Incremental models use a
   `lookback_days` var for late-arriving data.
4. **App-DB friendly marts.** Flat columns, no STRUCT/ARRAY, Postgres-compatible types, explicit
   primary key (+ surrogate key), audit columns (inputs, conversion table year, flags).
5. **Scoring is data, not code.** Conversion tables and the subject → KS2 test mapping live in seeds,
   keyed by year, so they can be updated without touching SQL.

## Scope rules (which responses are scored)
A response is in scope when its sitting is:
- not deleted, and belongs to a non-deleted pupil;
- style `fixed_question` or `non_adaptive`. `adaptive` is excluded (difficulty is tuned to the
  pupil, so % correct converges for everyone and stops measuring ability; proper scoring needs
  IRT, a README next step). Profiled: only 6 adaptive sittings, none in scored subjects, so this
  changes no current results and is kept as a production guard. `survey` has no right answers;
- for a scored subject (see mapping below).

There is **no year-group filter**: KS1 and KS2 sittings are both scored, and all of a pupil's
in-scope responses are pooled. Atom's content is graded by year, so a pupil's % correct is
performance on age-appropriate work. Year group is only used for labels:
`key_stage_at_score` = KS1 (Years 1–2), KS2 (3–6), `other` (null or outside 1–6; 25 sittings,
log them in the README). Profiled by assessment: 29 KS1-only (563 sittings), 69 KS2-only (1,655),
13 shared (276), 1 with no year group (15), which is why key stage comes from the sitting, not the
assessment.

Answered questions from incomplete sittings still count. Skipped questions (`is_no_attempt`)
count as answered and wrong.

## Scoring method (summary; full rationale in PLAN.md / README)
The seed holds the KS2 conversion tables for **2024, 2025 and 2026** (2024–2025 transcribed from
GOV.UK via a page fetch and cross-checked; 2026 from the page text supplied; all three re-verified
row-for-row by the script on 2026-10-20). To add a new year once STA publishes it (each July), run
`python scripts/build_ks2_conversion_seed.py --expect maths=N,reading=N,gps=N` (latest year by
default; `--year YYYY`, `--all`, `--check` to detect drift without writing, `--from-file` for a
saved page offline). It reads the GOV.UK Content API (stdlib only), validates each table (contiguous
raw marks, fixed paper totals, monotonic 80–120, all three tests), replaces only that year's rows
and saves the page body to `ai/sources/`. Never hand-edit the seed CSV. 2023 and earlier aren't loaded (GOV.UK no longer hosts
2023; Schools Week shows it only as images); load them only if profiling shows pre-2024 responses.

**Which table year applies:** macro `ks2_table_year(as_at)` = the latest year in the seed whose
`published_date` ≤ `as_at`, else the earliest year (fallback). `var('conversion_table_year')`
overrides it. One table per build, recorded in `conversion_table_year`, so history rebuilt for an
old `as_at` uses the table then in force. Known simplification: within one build, older responses
are scored with that build's table (README limitation).

Atom's assessments are shorter than real papers, so scoring goes through a percentage.
Per pupil × subject, using all in-scope responses up to the as-at date:
`pct_correct = n_correct / n_answered` → for each mapped KS2 test,
`floor(pct × max_raw_score)` → exact join to `seed_ks2_scaled_score_conversion` →
weighted average via `seed_subject_to_ks2_test` → round to an integer.
Raw 0–2 has no official score: clamp to 80, `has_official_scaled_score = false`.

A KS1 or Year 3–4 score means "performing at this level on age-appropriate work", an on-track
measure on the KS2 curve, not current SATs attainment. State this in the README. (Real KS1 tests
have their own 85–115 scale; switching to it later means adding a key stage column to the seeds.)

**Subject mapping** (`seed_subject_to_ks2_test`):
- Maths → maths (official).
- English → 0.5 reading + 0.5 gps (official, blended). Atom's SATs description of English is
  reading, spelling, vocabulary, grammar and punctuation, i.e. both reading and GPS, and topic
  names aren't available to split them.
- Science → proxy, ⅓ each of maths / reading / gps, with `is_proxy_score = true`. Science has no
  KS2 scaled score (it is not sat as a SATs test).
- Verbal Reasoning, Non-Verbal Reasoning (11+ aptitude, not KS2 curriculum), Wellbeing (not
  attainment) and Screeners (diagnostic) are excluded. "Every subject" is read as every subject
  with a defensible SATs equivalent; say so in the README.

| ks2_test | max raw | expected standard (100) | source |
|---|---|---|---|
| gps | 70 (50 questions + 20 spelling) | 34 | STA 2026 tables, published 16 Jul 2026 |
| reading | 50 | 25 | 〃 |
| maths | 110 (40 arithmetic + 70 reasoning) | 56 | 〃 |

Source pages are saved in `ai/sources/`. Never hard-code thresholds in SQL; they change yearly.

## First step: profile the data before building models
No models are written until profiling is done. Write one query per question as
`analyses/NN_<topic>.sql` (e.g. `01_row_counts.sql`), with a header comment stating what the
query checks and why it matters. Run them with `bq query`, dry-running first on anything
touching `responses`, and record results in `analyses/FINDINGS.md`.

Already profiled (record the exact numbers in FINDINGS.md): subjects, styles (6 adaptive
sittings), key-stage usage by assessment (see Scope rules).

Still to answer:
- **Grain and keys:** are `response_id`, `session_id`, `pupil_id` and `question_id` unique in
  their own tables? What are the row counts?
- **Orphans:** responses whose pupil, session or question is missing from the parent table,
  and responses or sittings belonging to deleted pupils.
- **Consistency:** does `responses.pupil_id` / `session_type` match the sitting? Does
  `total_questions` match the count of responses? Is `finished_at` ≥ `started_at`, and do
  responses fall inside the sitting window?
- **Values:** the distinct `session_type` and `year_group_at_sitting` values (what are the 25
  odd ones: Reception? Year 7+? null?), and `is_correct` vs `is_no_attempt` (can both be true?
  is `is_correct` null when skipped?).
- **Nulls and outliers:** null rates on key columns, negative or extreme `seconds_taken`,
  future or very old `answered_at`.
- **Re-attempts:** how often a pupil answers the same question more than once, and across
  how many sessions.
- **Per subject:** response volume, pupil count and `is_correct` null rate (confirms the
  Wellbeing / Screeners exclusions). Do Screener sittings contain questions from other subjects?
  Which subjects appear in KS1-only assessments?
- **Scope impact:** how many pupils, sittings and responses are dropped by each scope rule
  (deleted, adaptive / survey, excluded subjects).
- **Coverage:** pupils with no in-scope responses, and pupils with responses in only some
  subjects. The distribution of responses per pupil × subject sets the `is_low_confidence`
  threshold.
- **Date range** of `answered_at`: sets the default `as_at` and shows which conversion table
  years are actually needed (anything before 2024-07-09 falls back to the 2024 table).

`FINDINGS.md` format: one entry per check with the result (numbers), the decision taken, and
the affected rows. It becomes the README data quality log, so write it for a reviewer.

**Keep this file and PLAN.md current.** When a finding resolves an open decision, contradicts
an assumption here, or changes the model design, update CLAUDE.md (source table notes, open
decisions) and PLAN.md in the same commit, and say what changed in the commit message.
Never let the plan and the code disagree silently.

## Working with AI in this repo
- Save meaningful prompts / plans / session summaries into `ai/` (they are a submission requirement).
  `ai/planning_log.md` already records the planning decisions; append to it as the work goes.
- Commit in small steps with descriptive messages; don't squash, because the history is evidence.
- Before writing a model, check the profiling results in `analyses/`; use the column names above,
  don't invent new ones.
- When you make an assumption, add it to the README immediately, not at the end.
- Run `dbt build --select <model>+` after changes and fix failing tests rather than loosening them;
  if a test is loosened, explain why in the model's yml.
- <TODO: confirm> May Claude run `dbt build` / `bq query` against BigQuery without asking? Default: yes
  for `--dry_run` and anything on small tables; ask first before a full scan of `responses`.

## Open decisions (update as resolved)
- <TODO> **Which `session_type` values count** within the scored styles.
- <TODO> **Odd year groups** (25 sittings): they are scored and labelled `other`; confirm what the
  values are (Reception? Year 7+?) and whether any should be dropped.
- <TODO> **Re-attempts:** default is that every response counts (reflects performance at the time).
- <TODO> **Minimum responses** before a score is trusted (`is_low_confidence`); set it from the
  profiled distribution. A pupil with no in-scope responses gets a null score and
  `has_responses = false`.
- <TODO> **Subject exclusions:** confirm Wellbeing / Screeners behaviour in profiling (`is_correct`
  nulls, mixed-subject Screeners). Changing a mapping is a seed edit, not SQL.
- <TODO> **Conversion years needed:** check the `answered_at` range; add 2023 or earlier only if
  needed.
- DONE: KS1 and KS2 both scored on the one KS2 80–120 scale, labelled by year group; no key stage
  in the grain; no year-group filter.
- DONE: Pooled percentage scoring (tests are shorter than real papers).
- DONE: Subject mapping as above (English blended, Science proxy, four subjects excluded).
- DONE: Styles `fixed_question` / `non_adaptive` only.
- DONE: Conversion tables 2024–2026 loaded; table year chosen by `ks2_table_year(as_at)`.
- DONE: Correctness is binary (`is_correct` BOOLEAN), so there is no partial credit.
- DONE: Point-in-time uses `answered_at`; no load timestamp, so no bitemporal history.
