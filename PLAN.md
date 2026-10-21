# Plan: KS2 SATs scaled scores (≈2 hours)

> AI planning doc, kept in the repo as submission evidence: **what to build and in what order**.
> It has been kept in step with the code, but the reviewer-facing description of the final design
> is the README; how the design changed along the way is in `ai/planning_log.md`.

## Goal
Every non-deleted pupil gets, per subject they've done, a KS2 SATs-style scaled score of 80–120
(Maths and English) and % correct (all assessed subjects), in a long app table. The build is
re-runnable, can give the score as at any date, and produces a flat table ready for the app database.

**KS1 and KS2 pupils are both scored on the one KS2 80–120 scale**, because the brief defines the
scale as 80–120 and one curve is simplest. Each year group is scored separately (see below).

## Scoring: % correct → lookup table → scaled score
Atom's assessments are shorter than real SATs papers and vary in length, so a raw total can't be
looked up directly. (An earlier draft scored each mock as a full paper; it was dropped for this
reason.) For each pupil × subject × **year group** (of the sitting), adding up every in-scope
response from sittings in that year group up to the as-at date (scope rules in CLAUDE.md):

1. `percent_correct = 100 × n_correct / n_answered`. Skipped questions count as answered and wrong,
   as on a real paper. Repeated rows for one question in a sitting all count (each row is a mark);
   the README logs them as an identified issue (FINDINGS 25–28).
2. Round it down to a whole percent and look it up in `trf_percent_to_scaled_score`: one row per
   conversion year × subject × percent (0–100). The year is the academic year (Sep–Aug) of the
   pupil's latest response in that year group, so Sep 2025 – Aug 2026 uses the 2025 table,
   published the July before. A test fails if a Maths / English score finds no lookup row.
3. The lookup is built once from the conversion seeds: for each percent and each KS2 test the
   subject maps to, equivalent raw mark = floor(percent × full marks / 100) (floor, because a raw
   score counts marks earned), its official scaled score, then the weighted average
   (English = half reading, half GPS), rounded. Raw 0–2 has no official score, so counts as 80.
   Whole percents are coarser than raw marks on Maths (1% ≈ 1.1 marks), so a score just below a
   percent boundary can be ~1 point lower than an exact raw-mark calculation; 0.1% steps would be a
   one-number change.

Why not map the percentage linearly onto 80–120? The official curve isn't linear. 90% in maths
(99/110) scores 112 on the table, while a straight line gives 116.

**Caveats for the README:**
- KS1 and Year 3–4 pupils haven't reached the SATs stage, so their score is an on-track measure for
  age-appropriate work, not current SATs attainment. `year_group`
  is in the output so the app can label it. Real KS1 tests have
  their own 85–115 scale; using it would be a seed change (add a key stage column), noted as a
  next step.
- Scores are per year group, so a Year 5 score isn't diluted by Year 2 work. The current score is
  the latest year group's, so early in a new school year it rests on few responses.
- The conversion table follows the academic year, not calendar year: the 2026 table isn't
  published until July 2026, so calendar year would force a fallback and a later silent rescore.


## Subjects
The data has seven subjects, but only three KS2 tests (maths, reading, GPS) have a scaled score.
The mapping lives in `seeds/seed_subject_to_ks2_test.csv`, so changing a decision is a seed edit.

| subject_name | Treatment | Mapping | Why |
|---|---|---|---|
| Maths | official | maths 1.0 | A direct KS2 test |
| English | official, blended | reading 0.5 + gps 0.5 | Atom describes SATs English as reading, spelling, vocabulary, grammar and punctuation. Topic names aren't available (6 topic IDs only), so we can't split it; blending uses both real curves |
| Science | removed for now | none | No responses in the data, and not a SATs test. Re-add as a seed row if data arrives |
| Verbal Reasoning | excluded | none | 11+ aptitude skill, not KS2 curriculum |
| Non-Verbal Reasoning | excluded | none | Same |
| Wellbeing | excluded | none | Not attainment |
| Screeners | excluded | none | Diagnostic checks with no KS2 test (17% of responses) |

"Every subject" is read as every subject with a defensible SATs equivalent, which the README
explains. Profiling didn't support the original evidence (Screeners have right/wrong answers and
single-subject sittings), so the exclusion rests on what they are: diagnostics, not curriculum.

## Model design

```
de_raw.*  (source)
 └ stg_responses, stg_assessment_sittings, stg_pupils, stg_course_hierarchy     views
     only the columns used; drop is_deleted rows (pupils, sittings)
seed_ks2_scaled_scores_<year>  (one per year)
 └ stg_ks2_scaled_score_conversion           view; union all of the year seeds (generated)

── transform ──
 └ trf_percent_to_scaled_score               table; conversion year × subject × percent (0-100)
     → scaled score (English blended); built from the seeds
 └ trf_pupil_subject_daily                   incremental, insert_overwrite by answered_date
     joins staging, applies the scope rules, pupil × subject × year group × day: n_answered,
     n_correct; cluster by pupil_id, subject_name; lookback 3 days
── ready ──
 └ pupil_subject_year_scores                 table
     add up daily rows (up to var('as_at')) per pupil × subject × year group → % correct
     → left join the lookup on (academic year of the latest response, subject, whole percent)
 └ pupil_subject_sats_scores                 table, the app-DB output
     pupil × subject: the latest year group's row (QUALIFY ROW_NUMBER); no data → no row
```

**Point-in-time:** `--vars '{as_at: D}'` adds up only responses on or before D, so the year
scores and the current table are exactly what they were on D. There is no day-by-day history
table.
Event time is `answered_at`; there is no load timestamp, and the README says so.

**Re-runnable:** there is no `current_date()`; with no `as_at`, all data is used. The one
`row_number()` has a deterministic order (latest date, then highest year group). Check by building twice, then a full refresh, and
comparing row counts plus a checksum.

**Scale:** `trf_pupil_subject_daily` is incremental (insert_overwrite of the recent day
partitions); staging is views. The ready tables rebuild in full from the daily table, which is small.

**App-DB shape:** flat columns with Postgres-compatible types. The app table is long, keyed `(pupil_id, subject_name)`; the year table's key is `(pupil_id, subject_name,
year_group)` and holds the audit columns (`n_answered, n_correct, percent_correct, scaled_score,
conversion_table_year, last_answered_date`).

**Tests** (only where they add something): unique / not_null on the staging keys; a warning for
responses whose sitting is missing (a DQ finding); unique keys on every model that's joined or
served; mapping seed weights in (0, 1] and summing to 1 per subject; every Maths / English score
finds a conversion table; app table scaled scores in 80–120. The conversion seeds aren't
re-tested in dbt beyond a unique key: the fetch script validates them before writing.

## Timeline

| Time | Block | Output |
|---|---|---|
| 0:00–0:15 | **Setup** ✅: uv project, profile, `dbt_utils`, seed yml + singular tests, git init, docs, seeds and GOV.UK fetch script | `dbt debug` passes; first commit |
| 0:15–0:35 | **Profile** ✅: the "still to answer" list in CLAUDE.md, plus scope-impact counts | FINDINGS.md; open decisions resolved; docs updated |
| 0:35–0:55 | **Staging** ✅: sources yml + 4 views + tests | `dbt build -s staging` green |
| 0:55–1:30 | **Transform + ready** ✅ | `dbt build` green; tables in `james_oakley` |
| 1:30–1:40 | **Verify** ✅: run twice + full refresh; hand-check 3 pupils (one KS1, two English); one as-at run | Results in README |
| 1:40–2:00 | **README + push** ✅ (push pending): DQ log, scope and subject decisions, assumptions, next steps, GCSE paragraphs; AI notes into `ai/` | Repo pushed |

If you're running behind, cut in this order: make the transform models plain tables instead of
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
A `course_hierarchy` snapshot; topic names to split English into reading and
GPS properly; KS1 scoring on its own 85–115 scale (needs KS1 tables and a key stage column in the seeds);
2023 and earlier tables; recency weighting; IRT difficulty calibration
(would let adaptive sittings be scored, and Atom's questions aren't SATs questions); bitemporal
history if a load timestamp is added.
