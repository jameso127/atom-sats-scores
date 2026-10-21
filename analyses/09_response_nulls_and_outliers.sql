-- 09 Response nulls and outliers
-- Checks: null counts on every responses column; seconds_taken range, negatives and extremes;
-- answered_at range and future timestamps.
-- Why: sets the cleaning rules in stg_responses.
SELECT
    COUNT(*)                                         AS n_responses,
    COUNTIF(pupil_id IS NULL)                        AS n_null_pupil_id,
    COUNTIF(session_id IS NULL)                      AS n_null_session_id,
    COUNTIF(session_type IS NULL)                    AS n_null_session_type,
    COUNTIF(question_id IS NULL)                     AS n_null_question_id,
    COUNTIF(is_correct IS NULL)                      AS n_null_is_correct,
    COUNTIF(is_no_attempt IS NULL)                   AS n_null_is_no_attempt,
    COUNTIF(seconds_taken IS NULL)                   AS n_null_seconds_taken,
    COUNTIF(question_number IS NULL)                 AS n_null_question_number,
    COUNTIF(answered_at IS NULL)                     AS n_null_answered_at,
    MIN(seconds_taken)                               AS min_seconds_taken,
    MAX(seconds_taken)                               AS max_seconds_taken,
    APPROX_QUANTILES(seconds_taken, 100)[OFFSET(50)] AS p50_seconds_taken,
    APPROX_QUANTILES(seconds_taken, 100)[OFFSET(99)] AS p99_seconds_taken,
    COUNTIF(seconds_taken < 0)                       AS n_negative_seconds,
    COUNTIF(seconds_taken = 0)                       AS n_zero_seconds,
    COUNTIF(seconds_taken > 3600)                    AS n_over_1h_seconds,
    MIN(answered_at)                                 AS min_answered_at,
    MAX(answered_at)                                 AS max_answered_at,
    COUNTIF(answered_at > CURRENT_TIMESTAMP())       AS n_future_answered_at,
    MIN(question_number)                             AS min_question_number,
    MAX(question_number)                             AS max_question_number
FROM `atom-analytics-candidates.de_raw.responses`
