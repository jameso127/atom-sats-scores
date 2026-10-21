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
    COUNT(*)                                                                 AS n_sittings,
    COUNTIF(s.started_at IS NULL)                                            AS n_started_at_null,
    COUNTIF(s.finished_at IS NULL)                                           AS n_finished_at_null,
    COUNTIF(s.finished_at < s.started_at)                                    AS n_finished_before_started,
    COUNTIF(s.total_questions IS NULL)                                       AS n_total_questions_null,
    COUNTIF(rc.session_id IS NULL)                                           AS n_no_responses,
    COUNTIF(rc.n_responses = s.total_questions)                              AS n_responses_equal_total,
    COUNTIF(rc.n_responses < s.total_questions)                              AS n_responses_fewer_than_total,
    COUNTIF(rc.n_responses > s.total_questions)                              AS n_responses_more_than_total,
    COUNTIF(rc.n_responses > rc.n_distinct_questions)                        AS n_question_repeated_in_sitting,
    COUNTIF(s.is_complete)                                                   AS n_complete,
    COUNTIF(NOT s.is_complete)                                               AS n_incomplete,
    COUNTIF(s.is_complete AND rc.n_responses < s.total_questions)            AS n_complete_but_fewer_responses,
    APPROX_QUANTILES(TIMESTAMP_DIFF(s.finished_at, s.started_at, MINUTE), 4) AS duration_minutes_quartiles
FROM `atom-analytics-candidates.de_raw.assessment_sittings` AS s
LEFT JOIN response_counts AS rc ON s.session_id = rc.session_id
