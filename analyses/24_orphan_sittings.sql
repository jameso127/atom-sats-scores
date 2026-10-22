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
        resp.session_type,
        resp.question_id,
        resp.pupil_id,
        resp.session_id,
        resp.answered_at
    FROM `atom-analytics-candidates.de_raw.responses` AS resp
    LEFT JOIN `atom-analytics-candidates.de_raw.assessment_sittings` AS sitting
        ON resp.session_id = sitting.session_id
    WHERE sitting.session_id IS NULL
),

pupils_with_sittings AS (
    SELECT DISTINCT pupil_id
    FROM `atom-analytics-candidates.de_raw.assessment_sittings`
)

SELECT
    orph.session_type,
    question.subject_name,
    with_sit.pupil_id IS NOT NULL   AS pupil_has_valid_sittings,
    COUNT(*)                        AS n_responses,
    COUNT(DISTINCT orph.session_id) AS n_sittings,
    COUNT(DISTINCT orph.pupil_id)   AS n_pupils,
    MIN(orph.answered_at)           AS min_answered_at,
    MAX(orph.answered_at)           AS max_answered_at
FROM orphans AS orph
LEFT JOIN questions AS question ON orph.question_id = question.question_id
LEFT JOIN pupils_with_sittings AS with_sit ON orph.pupil_id = with_sit.pupil_id
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3
