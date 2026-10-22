-- 17 Scope impact
-- Checks: how many responses each scope rule removes, applied in order; each response is counted
-- at the first rule it fails. One scan of responses.
-- Why: the README scope section reports what each rule costs.
-- Scored subjects hard-coded as they were when run (Maths, English, Science). Science was later
-- removed from the mapping; it has no responses, so in-scope results are unchanged.
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
        LOGICAL_OR(is_deleted) AS is_deleted,
        ANY_VALUE(style)       AS style
    FROM `atom-analytics-candidates.de_raw.assessment_sittings`
    GROUP BY session_id
),

questions AS (
    SELECT
        question_id,
        ANY_VALUE(subject_name) AS subject_name
    FROM `atom-analytics-candidates.de_raw.course_hierarchy`
    GROUP BY question_id
),

classified AS (
    SELECT
        resp.pupil_id,
        resp.session_id,
        CASE
            WHEN pupil.pupil_id IS NULL THEN '1 pupil not found'
            WHEN pupil.is_deleted THEN '2 pupil deleted'
            WHEN sitting.session_id IS NULL THEN '3 sitting not found'
            WHEN sitting.is_deleted THEN '4 sitting deleted'
            WHEN sitting.style IS NULL OR sitting.style NOT IN ('fixed_question', 'non_adaptive')
                THEN '5 style ' || COALESCE(sitting.style, 'null')
            WHEN question.question_id IS NULL THEN '6 question not found'
            WHEN question.subject_name IS NULL OR question.subject_name NOT IN ('Maths', 'English', 'Science')
                THEN '7 subject ' || COALESCE(question.subject_name, 'null')
            ELSE '9 in scope'
        END AS outcome
    FROM `atom-analytics-candidates.de_raw.responses` AS resp
    LEFT JOIN pupils AS pupil ON resp.pupil_id = pupil.pupil_id
    LEFT JOIN sittings AS sitting ON resp.session_id = sitting.session_id
    LEFT JOIN questions AS question ON resp.question_id = question.question_id
)

SELECT
    outcome,
    COUNT(*)                                   AS n_responses,
    COUNT(DISTINCT pupil_id)                   AS n_pupils,
    COUNT(DISTINCT session_id)                 AS n_sittings,
    ROUND(COUNT(*) / SUM(COUNT(*)) OVER (), 4) AS pct_of_responses
FROM classified
GROUP BY outcome
ORDER BY outcome
