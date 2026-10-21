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
    COUNT(*)                                                     AS n_responses,
    COUNTIF(r.pupil_id IS NULL)                                  AS n_null_pupil_id,
    COUNTIF(r.pupil_id IS NOT NULL AND p.pupil_id IS NULL)       AS n_pupil_not_found,
    COUNTIF(p.is_deleted)                                        AS n_pupil_deleted,
    COUNTIF(r.session_id IS NULL)                                AS n_null_session_id,
    COUNTIF(r.session_id IS NOT NULL AND s.session_id IS NULL)   AS n_sitting_not_found,
    COUNTIF(s.is_deleted)                                        AS n_sitting_deleted,
    COUNTIF(r.question_id IS NULL)                               AS n_null_question_id,
    COUNTIF(r.question_id IS NOT NULL AND q.question_id IS NULL) AS n_question_not_found
FROM `atom-analytics-candidates.de_raw.responses` AS r
LEFT JOIN pupils AS p ON r.pupil_id = p.pupil_id
LEFT JOIN sittings AS s ON r.session_id = s.session_id
LEFT JOIN questions AS q ON r.question_id = q.question_id
