-- 02 Response orphans and deleted parents
-- Checks: responses whose pupil, sitting or question is null, missing from the parent table, or
-- belongs to a deleted pupil / sitting.
-- Why: orphans can't be scored (no subject, no sitting style); deleted parents must be excluded.
-- Parents are aggregated to one row per key so duplicate keys (see 01) can't fan out the join.
WITH pupils AS (
    SELECT
        pupil_id,
        LOGICAL_OR(is_deleted) AS is_deleted
    FROM `atom-analytics-candidates.de_raw.pupils`
    GROUP BY pupil_id
),

sittings AS (
    SELECT
        session_id,
        LOGICAL_OR(is_deleted) AS is_deleted
    FROM `atom-analytics-candidates.de_raw.assessment_sittings`
    GROUP BY session_id
),

questions AS (
    SELECT DISTINCT question_id
    FROM `atom-analytics-candidates.de_raw.course_hierarchy`
)

SELECT
    COUNT(*)                                                               AS n_responses,
    COUNTIF(resp.pupil_id IS NULL)                                         AS n_null_pupil_id,
    COUNTIF(resp.pupil_id IS NOT NULL AND pupil.pupil_id IS NULL)          AS n_pupil_not_found,
    COUNTIF(pupil.is_deleted)                                              AS n_pupil_deleted,
    COUNTIF(resp.session_id IS NULL)                                       AS n_null_session_id,
    COUNTIF(resp.session_id IS NOT NULL AND sitting.session_id IS NULL)    AS n_sitting_not_found,
    COUNTIF(sitting.is_deleted)                                            AS n_sitting_deleted,
    COUNTIF(resp.question_id IS NULL)                                      AS n_null_question_id,
    COUNTIF(resp.question_id IS NOT NULL AND question.question_id IS NULL) AS n_question_not_found
FROM `atom-analytics-candidates.de_raw.responses` AS resp
LEFT JOIN pupils AS pupil ON resp.pupil_id = pupil.pupil_id
LEFT JOIN sittings AS sitting ON resp.session_id = sitting.session_id
LEFT JOIN questions AS question ON resp.question_id = question.question_id
