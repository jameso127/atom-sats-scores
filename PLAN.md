# Plan: KS2 SATs scaled scores (≈2 hours)

> AI planning doc, kept in the repo as submission evidence. Schemas, conventions, scope rules and
> open decisions are in `CLAUDE.md`; this file covers **what to build and in what order**.

## Goal
Every non-deleted pupil × scored subject gets a KS2 SATs-style scaled score of 80–120. The build is
re-runnable, can give the score as at any date, and produces a flat table ready for the app database.

**KS1 and KS2 pupils are both scored on the one KS2 80–120 scale**, because the brief defines the
scale as 80–120 and one curve is simplest. Year group is a label, not a filter (see below).

## Scoring: percentage → equivalent raw mark → official table
Atom's assessments are shorter than real SATs papers and vary in length, so a raw total can't be
looked up directly. (An earlier draft scored each mock as a full paper; it was dropped for this
reason.) For each pupil × subject, using in-scope responses up to the as-at date
(scope rules in CLAUDE.md: scored styles, scored subjects, not deleted; no year-group filter):

1. `pct_correct = n_correct / n_answered`. Skipped questions count as answered and wrong, as on a
   real paper.
2. For each KS2 test the subject maps to: `equivalent_raw = floor(pct_correct × max_raw_score)`.
   We floor because a raw score counts marks earned; rounding would award threshold marks not earned.
3. Look up `equivalent_raw` in `seed_ks2_scaled_score_conversion` for a scaled score. The table year
   is `ks2_table_year(as_at)`: the latest of 2024 / 2025 / 2026 published on or before `as_at`
   (earliest as fallback), overridable with a var, and stored in `conversion_table_year`.
4. If the subject maps to more than one test, take the weighted average of the scaled scores and
   round to an integer.
5. Raw 0–2 has no official score, so clamp to 80 and set `has_official_scaled_score = false`.

Why not map the percentage linearly onto 80–120? The official curve isn't linear. 90% in maths
(99/110) scores 112 on the table, while a straight line gives 116.

**Caveats for the README:**
- KS1 and Year 3–4 pupils haven't reached the SATs stage, so their score is an on-track measure for
  age-appropriate work, not current SATs attainment. `latest_year_group` and `key_stage_at_score`
  (KS1 = Years 1–2, KS2 = 3–6, other) are in the output so the app can label it. Real KS1 tests have
  their own 85–115 scale; using it would be a seed change (add a key stage column), noted as a
  next step.
- All a pupil's responses are pooled across years, which is reasonable because content is graded by
  year group. It is a simplification.
- One conversion table per build: older responses are scored with the table in force at `as_at`,
  not the table of their own year. Fixing that needs history rows at each table's publication date.


## Subjects
The data has seven subjects, but only three KS2 tests (maths, reading, GPS) have a scaled score.
The mapping lives in `seeds/seed_subject_to_ks2_test.csv`, so changing a decision is a seed edit.

| subject_name | Treatment | Mapping | Why |
|---|---|---|---|
| Maths | official | maths 1.0 | A direct KS2 test |
| English | official, blended | reading 0.5 + gps 0.5 | Atom describes SATs English as reading, spelling, vocabulary, grammar and punctuation. Topic names aren't available (5 topic IDs only), so we can't split it; blending uses both real curves |
| Science | proxy, flagged | maths, reading, gps ⅓ each | In the curriculum but not a SATs test. A generic KS2 curve is the most honest stand-in; `is_proxy_score = true` |
| Verbal Reasoning | excluded | none | 11+ aptitude skill, not KS2 curriculum |
| Non-Verbal Reasoning | excluded | none | Same |
| Wellbeing | excluded | none | Not attainment |
| Screeners | excluded | none | Diagnostic checks, not a subject |

"Every subject" is read as every subject with a defensible SATs equivalent, which the README
explains. Profiling confirms the exclusions (`is_correct` nulls, mixed-subject screeners).

## Model design

```
raw_de.*  (source)
 └ stg_responses, stg_assessment_sittings, stg_pupils, stg_course_hierarchy     views
     cast, rename, drop is_deleted rows (pupils, sittings)
 └ int_responses_scored                      incremental (merge on response_id)
     response + sitting + question → subject_name; apply the scope rules; scored subjects only
     partition by date(answered_at), cluster by pupil_id, subject_name; lookback var (3 days)
 └ int_pupil_subject_daily                   incremental (merge on pupil, subject, date)
     pupil × subject × answered_date: n_answered, n_correct, year group of the day's last response
 └ fct_pupil_subject_score_history           table
     running totals → one row per pupil × subject × day with activity
     pct → equivalent raw per mapped test → seed lookup → weighted scaled score
     valid_from = that day, valid_to = next activity day (null = current)
 └ pupil_subject_sats_scores                 table, the app-DB output
     pupils × scored subjects (cross join on small tables), left join history as at var('as_at')
     no in-scope data → row kept, scaled_score null, has_responses = false
```

**Point-in-time:** the score as at D is the history row where
`valid_from <= D and (valid_to > D or valid_to is null)`, held in a macro `as_at_filter(d)`.
Event time is `answered_at`; there is no load timestamp, and the README says so.

**Re-runnable:** there is no `current_date()`. `as_at` defaults to the maximum `answered_at`.
Window functions have deterministic ordering. Check by building twice, then a full refresh, and
comparing row counts plus a checksum.

**Scale:** only `int_responses_scored` touches `responses`, and it does so incrementally.
Downstream reads the daily table, which is far smaller. History is a full rebuild from daily for now,
and incremental is a README next step.

**App-DB shape:** flat columns with Postgres-compatible types. The current table's primary key is
`(pupil_id, subject_name)` and the history's is `(pupil_id, subject_name, valid_from)`, each with a
surrogate `score_id`. Audit columns: `n_answered, n_correct, pct_correct, scoring_method,
is_proxy_score, has_official_scaled_score, has_responses, is_low_confidence,
meets_expected_standard, latest_year_group, key_stage_at_score, conversion_table_year, as_at_date`.

**Tests:** unique / not_null on every key; relationships from responses to pupils, sittings and
questions (severity: warn, as orphans are a DQ finding); seed weights sum to 1 per subject; each conversion year has all three tests; conversion table is monotonic;
`pct_correct` in 0–1; scaled score in the range 80–120; pupils × scored subjects = current row count.

## Timeline

| Time | Block | Output |
|---|---|---|
| 0:00–0:15 | **Setup** ✅: uv project, profile, `dbt_utils`, `generate_schema_name`, `ks2_table_year` / `as_at_filter` macros, seed yml + singular tests, git init, docs, seeds and GOV.UK fetch script | `dbt debug` passes; first commit |
| 0:15–0:35 | **Profile**: the "still to answer" list in CLAUDE.md, plus scope-impact counts | FINDINGS.md; open decisions resolved; docs updated |
| 0:35–0:55 | **Staging**: sources yml + 4 views + tests | `dbt build -s staging` green |
| 0:55–1:30 | **Intermediate + marts** + `as_at_filter` | `dbt build` green; tables in `james_oakley` |
| 1:30–1:40 | **Verify**: run twice + full refresh; hand-check 3 pupils (one English, one Science); one as-at run | Results in README |
| 1:40–2:00 | **README + push**: DQ log, scope and subject decisions, assumptions, next steps, GCSE paragraphs; AI notes into `ai/` | Repo pushed |

If you're running behind, cut in this order: make the intermediates plain tables instead of
incremental, then the as-at run, then the GCSE section. Never cut the DQ log, the scope and
subject rationale, or the re-run check.

## GCSE prediction (README, ~3 paragraphs)
The target is the GCSE grade (9–1) by subject. Features: scaled scores and their trajectory,
engagement (volume, consistency, time taken), topic-level strengths, VR/NVR as aptitude signals
(useful here even though they're excluded from SATs), and school context, used carefully for
fairness. The essential data is **linked outcomes**: real GCSE results for past platform users,
which means 5+ years of history or a National Pupil Database link. Assumptions: our scores mean the
same over time, past cohorts resemble future ones, and the KS2 → KS4 relationship is stable. The
DfE's KS2 → KS4 transition data is the baseline to beat. Report the result as a grade
distribution, not a single grade.

## Next steps (README)
Incremental history; a `course_hierarchy` snapshot; topic names to split English into reading and
GPS properly; KS1 scoring on its own 85–115 scale (needs KS1 tables and a key stage column in the seeds);
history rows at each conversion table's publication date; 2023 and earlier tables; recency weighting; IRT difficulty calibration
(would let adaptive sittings be scored, and Atom's questions aren't SATs questions); bitemporal
history if a load timestamp is added.
