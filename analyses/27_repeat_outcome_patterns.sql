-- 27 Outcomes within repeated question rows
-- Checks: for each repeated pupil × sitting × question, how many rows and how many correct, plus
-- skips.
-- Why: shows what each collapsing rule (keep all, max = any correct, min, mean) would do to the
-- score, and whether the conflicting rows look like partial marks.
WITH repeats AS (
    SELECT
        session_id,
        question_id,
        COUNT(*)               AS n_rows,
        COUNTIF(is_correct)    AS n_correct,
        COUNTIF(is_no_attempt) AS n_skipped
    FROM `atom-analytics-candidates.de_raw.responses`
    GROUP BY session_id, question_id
    HAVING COUNT(*) > 1
)

SELECT
    n_rows,
    n_correct,
    n_skipped,
    COUNT(*) AS n_pupil_questions
FROM repeats
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3
