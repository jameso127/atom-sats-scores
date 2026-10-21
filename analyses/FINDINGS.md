# Profiling findings

Source: `atom-analytics-candidates.de_raw`, profiled 2026-10-20. Each entry gives the query
(`analyses/NN_*.sql`, result in `analyses/results/NN_*.csv`), the result, the decision taken and
the rows affected. This becomes the README data quality log.

**Headline:** the data is small (63,707 responses, 2,509 sittings, 242 pupils) and mostly clean:
keys are unique, there are no nulls in key columns and no soft-deleted rows. The issues that
matter for scoring are **orphan sittings (2.2% of responses)**, **repeated question rows
within a sitting (7.1%)**, **no Science responses at all**, and a **constant `session_type` on
responses**. In scope: **46,555 responses (73.1%), 156 pupils, 1,721 sittings**, English and Maths only.

All decisions below were confirmed with the user on 2026-10-20.

---

## Grain and keys

### 01 Primary keys
| table | rows | distinct key | null key |
|---|---|---|---|
| responses | 63,707 | 63,707 | 0 |
| assessment_sittings | 2,509 | 2,509 | 0 |
| pupils | 242 | 242 | 0 |
| course_hierarchy | 10,552 | 10,552 | 0 |

**Decision:** `response_id`, `session_id`, `pupil_id`, `question_id` are the primary keys; keep
`unique` + `not_null` tests on them (source tests on the three small tables, staging test on
responses). **Affected:** none.

## Orphans and soft deletes

### 02 / 24 Responses whose sitting is missing
1,433 responses (2.2%) in **56 session_ids that don't exist in `assessment_sittings`**, from
44 pupils. Every other parent exists (no missing pupils or questions). From 24: they span the
whole date range (2025-11-11 → 2026-06-12), all their pupils also have valid sittings, and by
subject they are English 889, Maths 307, Screeners 141, Wellbeing 96. This looks like sittings
lost from the sittings table, not junk responses.

**Decision:** exclude. Without the sitting there's no style, deleted flag or year group, so the
scope rules can't be applied. Relationship test `responses.session_id → sittings` at
`severity: warn`; noted in the README data quality log. **Affected:** 1,196 English + Maths
responses that would otherwise be in scope (2.5% of in-scope volume), across at most 40
pupil-subject combinations. *Next step:* the pupils exist and the question gives the subject, so
these could still be scored if a style is assumed (all known English / Maths sittings are
fixed_question).

### 02 / 03 Soft deletes
0 deleted pupils, 0 deleted sittings, no null `is_deleted` values.

**Decision:** keep the `is_deleted` filters in staging as a production guard. They change no
current results. **Affected:** none.

### 03 Inactive pupils and empty sittings
61 of 242 pupils have no sittings; 79 sittings have no responses (22: all 6 adaptive, all 8
non_adaptive, all 26 entrance_exam, 39 summative fixed_question).

**Decision:** keep every non-deleted pupil in the output ("every pupil"), with
`has_responses = false` and a null score. Empty sittings don't matter (scoring reads responses).

## Consistency

### 04 / 20 `session_type` on responses is constant
Every response has `session_type = 'MOCK_TEST'`; sittings use `summative_assessment`,
`entrance_exam`, `mock_session`. The 100% "mismatch" in 04 is this, not a join problem.
`pupil_id` on responses matches the sitting in all 62,274 joinable rows.

**Decision:** drop `responses.session_type` in staging; take `session_type` from the sitting.
Open decision "which session_type values count" is resolved: **no session_type filter**. All
responses with a sitting come from `summative_assessment` sittings (22); `entrance_exam` and
`mock_session` sittings have no responses. The style rule is the only one needed. **Affected:** none.

### 04 / 05 Sitting timing
- 1,608 responses answered after their sitting's `finished_at` (none by more than an hour);
  0 before `started_at`.
- 12 sittings with null `started_at`, 13 with null `finished_at`; 0 finish-before-start.
- Duration quartiles 0 / 6 / 15 / 24 minutes; max 68,382 minutes (47 days) on one sitting.

**Decision:** no window filtering. `answered_at` is the event time, and sitting timestamps are not
used in scoring. Logged as DQ only. **Affected:** none.

### 05 / 11 / 21 / 25–28 Repeated questions within a sitting
2,082 pupil × question pairs appear more than once (4,493 responses, 7.1%), **always within the
same sitting** (11: never across sittings, so there are no true re-attempts). From 21: every
repeat has the **same `answered_at` and the same `question_number`**, yet the first and last rows
have different outcomes in 904 of the 2,082 pairs (one right, one wrong). This also explains 05's 747 sittings with more
responses than `total_questions` (749 sittings contain a repeat).

Two readings: (a) **multi-part / multi-mark questions** recorded as one row per mark, or
(b) **duplicate events** with conflicting outcomes. Follow-ups:

- **25:** in 709 of the 749 sittings with repeats, `total_questions` equals the number of
  **distinct questions** (only 2 match the row count; 38 match neither). The paper counts each
  question once.
- **26:** English and Maths questions are repeated in **some sittings but not others** (English:
  78 questions, repeated in 1,163 of 1,733 sittings they appear in; Maths: 46 questions, 633 of
  986). A multi-mark question would repeat every time with the same row count. Only Verbal
  Reasoning (not scored) looks structural (37 questions with the same row count in every sitting).
- **27:** repeats run 2–5 rows; none are skips; outcomes are mixed (e.g. of 1,837 two-row
  repeats, 365 both wrong, 799 one right, 673 both right).
- **28:** effect on average pupil % correct (English / Maths): keep all rows 57.8% / 57.6%;
  **max (correct if any row correct) 58.7% / 58.3%**; mean 57.8% / 57.4%; min 56.9% / 56.5%.
  Max moves 37 pupil-subjects by 2+ points; the largest single gain is 5.2 points.

**Decision (user):** **keep every row**: each row counts as one answered mark and each correct row as
one correct mark. The evidence points to duplicates (b), but which row is "real" can't be told
apart (identical timestamps), and keeping all rows is neutral: the same average as a mean-collapse,
with no upward bias (unlike max). Logged in the README as an identified issue. Re-attempts across
sittings: none exist. **Affected:** 4,493 rows (7.1%), all counted.

### 06 / 22 Styles
| style | session_type | sittings | with responses |
|---|---|---|---|
| fixed_question | summative_assessment | 2,344 | 2,305 |
| fixed_question | entrance_exam | 26 | 0 |
| survey | summative_assessment | 125 | 125 (all Wellbeing) |
| non_adaptive | mock_session | 8 | 0 |
| adaptive | mock_session | 6 | 0 |

**Decision:** keep the style rule (`fixed_question`, `non_adaptive`). The adaptive exclusion and
`non_adaptive` inclusion change nothing today; all scored data is `fixed_question`. **Affected:**
3,936 survey responses excluded.

## Values

### 07 / 15 / 23 Year groups
Years 1–6: 2,484 sittings. "Other": 25 sittings with **year groups 11, 14 and 15**, all
`entrance_exam`, in 2 assessments, from pupils with no Year 1–6 sittings, and with **no
responses**. There are no null year groups (CLAUDE.md said one assessment had none; in fact it's
these values). By assessment (15): 29 KS1-only (563 sittings), 68 KS2-only (1,644), 13 shared
(276), 1 KS2 + other (11), 1 other-only (15).

**Decision:** keep the `other` label (`key_stage_at_score`); it affects no scored rows today.
Open decision "odd year groups" is resolved. **Affected:** none scored.

### 08 `is_correct` vs `is_no_attempt`
| is_correct | is_no_attempt | responses |
|---|---|---|
| false | false | 24,047 |
| false | true | 3,279 |
| true | false | 36,381 |

`is_correct` is never null, and is always false when skipped.

**Decision:** `n_correct = countif(is_correct)`, `n_answered = count(*)`; skips count as answered
and wrong, as planned. **Affected:** 3,279 skipped responses counted as wrong.

### 09 Nulls and outliers
- No nulls anywhere except `seconds_taken` (25 rows).
- `seconds_taken`: min 0, median 16, p99 172, max 1,178; no negatives; **3,156 rows of 0 seconds**.
- `question_number` 1–50. No future `answered_at`.

**Decision:** `seconds_taken` isn't used in scoring; pass it through as is (null and 0 noted).

## Subjects

### 12 Course hierarchy
Each question has exactly one subject; one `subject_id` per `subject_name`; no missing levels.
| subject | questions | atoms | subtopics | topics |
|---|---|---|---|---|
| English | 4,699 | 65 | 15 | **6** |
| Maths | 3,593 | 86 | 21 | 7 |
| Non-Verbal Reasoning | 844 | 6 | 4 | 2 |
| Verbal Reasoning | 807 | 5 | 4 | 3 |
| Science | 335 | 37 | 16 | 4 |
| Screeners | 181 | 7 | 3 | 1 |
| Wellbeing | 93 | 6 | 3 | 1 |

**Decision:** subject comes from `course_hierarchy`; no double-counting risk. English has 6
topics, not 5 as CLAUDE.md said (corrected).

### 13 / 14 Responses by subject
| subject | responses | pupils | % skipped | % correct |
|---|---|---|---|---|
| English | 28,489 | 154 | 1.9% | 58.2% |
| Maths | 19,262 | 152 | 4.9% | 57.7% |
| Screeners | 11,089 | 82 | 15.8% | 52.4% |
| Wellbeing | 4,032 | 129 | 0.3% | 61.0% |
| Verbal Reasoning | 691 | 8 | 3.8% | 48.5% |
| Non-Verbal Reasoning | 144 | 3 | 2.8% | 63.9% |
| **Science** | **0** | — | — | — |

Every sitting contains exactly one subject (14), so **Screeners are not mixed-subject**.

- **Science has questions but no responses.** **Decision:** removed from
  `seed_subject_to_ks2_test` for now, with a README note; re-adding it is a seed edit.
- **Screeners.** The planned evidence for excluding them (null `is_correct`, mixed subjects)
  doesn't hold: they have right/wrong answers and single-subject sittings. **Decision:** no scaled
  score, because they're diagnostic checks, not a curriculum subject with a KS2 test; the app table
  shows their % correct only (as for Verbal / Non-Verbal Reasoning). They are 10,948 responses (17%).
- Wellbeing is excluded by style anyway (all `survey`) and by subject.

### 16 Subjects by key stage
English: KS1 6,588 / KS2 21,012. Maths: KS1 5,247 / KS2 13,708 (52 KS1 pupils in each).
Everything else is KS2 only, apart from Wellbeing.

**Decision:** KS1 pupils are scored in English and Maths, labelled KS1 ("on track for KS2").

## Scope, coverage, dates

### 17 Scope impact (each response counted at the first rule it fails)
Run when only Maths / English were in scope. Screeners and Verbal / Non-Verbal Reasoning were later
brought back for % correct (no scaled score), so the three `subject ...` rows below now count
towards % correct; the scaled-score scope is still the 46,555 Maths / English responses.
| outcome | responses | % | pupils | sittings |
|---|---|---|---|---|
| sitting not found | 1,433 | 2.2% | 44 | 56 |
| style survey | 3,936 | 6.2% | 125 | 125 |
| subject Screeners | 10,948 | 17.2% | 82 | 568 |
| subject Verbal Reasoning | 691 | 1.1% | 8 | 13 |
| subject Non-Verbal Reasoning | 144 | 0.2% | 3 | 3 |
| **in scope** | **46,555** | **73.1%** | **156** | **1,721** |

Deleted pupils / sittings, adaptive style and missing questions remove nothing.

### 18 / 19 Coverage
- Pupils by scored subjects with data: 150 English + Maths, 4 English only, 2 Maths only,
  **86 none**.
- Output: a long app table, one row per pupil × subject with responses. 154 pupils have an English
  scaled score and 152 a Maths one; 88 / 90 have no row for that subject.
- In-scope responses per pupil-subject (when > 0): English deciles 6 / 33 / 88 / 122 / 167 / 179 /
  203 / 243 / 280 / 289 / 322; Maths 25 / 35 / 73 / 101 / 138 / 142 / 144 / 167 / 171 / 178 / 189.
  Only 1 pupil-subject (English, 6 responses) has fewer than 20. (These counts are before
  collapsing duplicates.)

**Decision:** **no low-confidence flag and no minimum-response filter.** All of a pupil's in-scope
responses are pooled into one % correct, and `n_answered` / `n_correct` are output so the app can
judge reliability. A per-sitting question-count filter isn't needed: only 10 sittings have fewer
responses than `total_questions` (05), and incomplete sittings still count.

### 10 Date range
`answered_at` runs **2025-11-10 → 2026-09-16**. By academic year: 2025/26 = 61,960 responses
(2025 table), Sep 2026 = 1,747 (2026 table). No activity in Aug 2026; Mar–Apr 2026 almost empty
(43 responses).

**Decision:** default `as_at` = max `answered_at` (2026-09-16). Open decision "conversion years
needed" is resolved: the data needs the 2025 and 2026 tables; 2024 is loaded but unused; no
pre-2024 tables needed.

---

## Verification (models built 2026-10-21)
Queries 29–31 check the built models rather than the source; results are in the README
"Verification" section: identical checksums across a full refresh and an incremental run, four
hand-checked scores matching a recomputation from `de_raw`, and the score distribution.
