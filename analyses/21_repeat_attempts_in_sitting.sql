-- 21 Repeated questions within one sitting
-- Checks: for questions a pupil answered more than once (always within one sitting, per 11),
-- whether the rows are exact duplicates (same answered_at / question_number / outcome) or real
-- retries, and how the outcome changes between first and last attempt.
-- Why: duplicates should be removed; genuine retries are a scoring decision (first, last or all).
WITH repeats AS (
    SELECT
        pupil_id,
        session_id,
        question_id,
        COUNT(*)                                                                             AS n_attempts,
        COUNT(DISTINCT answered_at)                                                          AS n_distinct_answered_at,
        COUNT(DISTINCT question_number)                                                      AS n_distinct_question_number,
        COUNT(DISTINCT is_correct)                                                           AS n_distinct_outcomes,
        ARRAY_AGG(is_correct ORDER BY answered_at, response_id LIMIT 1)[OFFSET(0)]           AS first_correct,
        ARRAY_AGG(is_correct ORDER BY answered_at DESC, response_id DESC LIMIT 1)[OFFSET(0)] AS last_correct,
        TIMESTAMP_DIFF(MAX(answered_at), MIN(answered_at), SECOND)                           AS seconds_first_to_last
    FROM `atom-analytics-candidates.de_raw.responses`
    GROUP BY pupil_id, session_id, question_id
    HAVING COUNT(*) > 1
)

SELECT
    n_distinct_answered_at = 1                 AS is_same_timestamp,
    n_distinct_question_number = n_attempts    AS is_distinct_question_numbers,
    first_correct,
    last_correct,
    COUNT(*)                                   AS n_pupil_questions,
    SUM(n_attempts)                            AS n_responses,
    APPROX_QUANTILES(seconds_first_to_last, 4) AS seconds_first_to_last_quartiles
FROM repeats
GROUP BY 1, 2, 3, 4
ORDER BY 1, 2, 3, 4
