-- 24 Responses whose sitting is missing
-- Checks: for the 56 session_ids in responses but not in assessment_sittings (see 02), their date
-- range, response session_type, subjects and whether the pupils also have valid sittings.
-- Why: these responses have no style or deleted flag, so the scope rule drops them; this shows
-- whether that loses a pattern (e.g. a date range or session type missing from sittings).
WITH questions AS (
    SELECT
        question_id,
        ANY_VALUE(subject_name) AS subject_name
    FROM `atom-analytics-candidates.de_raw.course_hierarchy`
    GROUP BY question_id
),

orphans AS (
    SELECT
        r.session_type,
        r.question_id,
        r.pupil_id,
        r.session_id,
        r.answered_at
    FROM `atom-analytics-candidates.de_raw.responses` AS r
    LEFT JOIN `atom-analytics-candidates.de_raw.assessment_sittings` AS s
        ON r.session_id = s.session_id
    WHERE s.session_id IS NULL
),

pupils_with_sittings AS (
    SELECT DISTINCT pupil_id
    FROM `atom-analytics-candidates.de_raw.assessment_sittings`
)

SELECT
    o.session_type,
    q.subject_name,
    pws.pupil_id IS NOT NULL     AS pupil_has_valid_sittings,
    COUNT(*)                     AS n_responses,
    COUNT(DISTINCT o.session_id) AS n_sittings,
    COUNT(DISTINCT o.pupil_id)   AS n_pupils,
    MIN(o.answered_at)           AS min_answered_at,
    MAX(o.answered_at)           AS max_answered_at
FROM orphans AS o
LEFT JOIN questions AS q ON o.question_id = q.question_id
LEFT JOIN pupils_with_sittings AS pws ON o.pupil_id = pws.pupil_id
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3
