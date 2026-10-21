-- 03 Sitting orphans and deleted pupils
-- Checks: sittings whose pupil is missing or deleted, deleted sittings, sittings with no responses,
-- and pupils with no sittings.
-- Why: decides where the is_deleted filters go, and whether "every pupil" includes inactive ones.
WITH pupils AS (
    SELECT
        pupil_id,
        LOGICAL_OR(is_deleted)      AS is_deleted,
        COUNTIF(is_deleted IS NULL) AS n_null_deleted
    FROM `atom-analytics-candidates.de_raw.pupils`
    GROUP BY pupil_id
),

sitting_responses AS (
    SELECT DISTINCT session_id
    FROM `atom-analytics-candidates.de_raw.responses`
),

sittings AS (
    SELECT
        s.session_id,
        s.pupil_id,
        s.is_deleted,
        p.pupil_id IS NULL            AS is_pupil_missing,
        COALESCE(p.is_deleted, FALSE) AS is_pupil_deleted,
        sr.session_id IS NULL         AS has_no_responses
    FROM `atom-analytics-candidates.de_raw.assessment_sittings` AS s
    LEFT JOIN pupils AS p ON s.pupil_id = p.pupil_id
    LEFT JOIN sitting_responses AS sr ON s.session_id = sr.session_id
),

pupils_with_sittings AS (
    SELECT DISTINCT pupil_id
    FROM sittings
    WHERE pupil_id IS NOT NULL
)

SELECT
    (SELECT COUNT(*) FROM sittings)                    AS n_sittings,
    (SELECT COUNTIF(is_deleted) FROM sittings)         AS n_sittings_deleted,
    (SELECT COUNTIF(is_deleted IS NULL) FROM sittings) AS n_sittings_is_deleted_null,
    (SELECT COUNTIF(is_pupil_missing) FROM sittings)   AS n_sittings_pupil_not_found,
    (SELECT COUNTIF(is_pupil_deleted) FROM sittings)   AS n_sittings_pupil_deleted,
    (SELECT COUNTIF(has_no_responses) FROM sittings)   AS n_sittings_no_responses,
    (SELECT COUNT(*) FROM pupils)                      AS n_pupils,
    (SELECT COUNTIF(is_deleted) FROM pupils)           AS n_pupils_deleted,
    (SELECT SUM(n_null_deleted) FROM pupils)           AS n_pupils_is_deleted_null,
    (
        SELECT COUNT(*) FROM pupils                    AS p
        LEFT JOIN pupils_with_sittings                 AS ps ON p.pupil_id = ps.pupil_id
        WHERE ps.pupil_id IS NULL
    )                                                  AS n_pupils_no_sittings
