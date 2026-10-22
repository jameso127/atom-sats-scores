-- 05 Sitting timings and question counts
-- Checks: finished_at >= started_at; total_questions vs the number of responses; repeated questions
-- within a sitting; is_complete vs response count.
-- Why: shows whether incomplete sittings and skipped questions are recorded as rows, which affects
-- how n_answered is counted.
WITH response_counts AS (
    SELECT
        session_id,
        COUNT(*)                    AS n_responses,
        COUNT(DISTINCT question_id) AS n_distinct_questions
    FROM `atom-analytics-candidates.de_raw.responses`
    GROUP BY session_id
)

SELECT
    COUNT(*)                                                                             AS n_sittings,
    COUNTIF(sitting.started_at IS NULL)                                                  AS n_started_at_null,
    COUNTIF(sitting.finished_at IS NULL)                                                 AS n_finished_at_null,
    COUNTIF(sitting.finished_at < sitting.started_at)                                    AS n_finished_before_started,
    COUNTIF(sitting.total_questions IS NULL)                                             AS n_total_questions_null,
    COUNTIF(resp_counts.session_id IS NULL)                                              AS n_no_responses,
    COUNTIF(resp_counts.n_responses = sitting.total_questions)                           AS n_responses_equal_total,
    COUNTIF(resp_counts.n_responses < sitting.total_questions)                           AS n_responses_fewer_than_total,
    COUNTIF(resp_counts.n_responses > sitting.total_questions)                           AS n_responses_more_than_total,
    COUNTIF(resp_counts.n_responses > resp_counts.n_distinct_questions)                  AS n_question_repeated_in_sitting,
    COUNTIF(sitting.is_complete)                                                         AS n_complete,
    COUNTIF(NOT sitting.is_complete)                                                     AS n_incomplete,
    COUNTIF(sitting.is_complete AND resp_counts.n_responses < sitting.total_questions)   AS n_complete_but_fewer_responses,
    APPROX_QUANTILES(TIMESTAMP_DIFF(sitting.finished_at, sitting.started_at, MINUTE), 4) AS duration_minutes_quartiles
FROM `atom-analytics-candidates.de_raw.assessment_sittings` AS sitting
LEFT JOIN response_counts AS resp_counts ON sitting.session_id = resp_counts.session_id
