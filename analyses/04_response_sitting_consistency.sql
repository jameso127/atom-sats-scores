-- 04 Responses agree with their sitting
-- Checks: responses.pupil_id and session_type match the sitting; answered_at falls inside the
-- sitting's started_at..finished_at window.
-- Why: decides whether pupil and session_type are taken from the response or the sitting, and
-- whether answered_at can be trusted as event time.
-- Assumes session_id is unique in assessment_sittings (see 01).
SELECT
    COUNT(*)                                                           AS n_responses_with_sitting,
    COUNTIF(r.pupil_id IS DISTINCT FROM s.pupil_id)                    AS n_pupil_mismatch,
    COUNTIF(r.session_type IS DISTINCT FROM s.session_type)            AS n_session_type_mismatch,
    COUNTIF(r.answered_at IS NULL)                                     AS n_answered_at_null,
    COUNTIF(r.answered_at < s.started_at)                              AS n_answered_before_start,
    COUNTIF(r.answered_at > s.finished_at)                             AS n_answered_after_finish,
    COUNTIF(TIMESTAMP_DIFF(s.started_at, r.answered_at, MINUTE) > 60)  AS n_answered_over_1h_before_start,
    COUNTIF(TIMESTAMP_DIFF(r.answered_at, s.finished_at, MINUTE) > 60) AS n_answered_over_1h_after_finish
FROM `atom-analytics-candidates.de_raw.responses` AS r
INNER JOIN `atom-analytics-candidates.de_raw.assessment_sittings` AS s
    ON r.session_id = s.session_id
