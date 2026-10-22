-- 16 Subjects by key stage
-- Checks: responses, pupils and sittings per subject × key stage of the sitting.
-- Why: shows which subjects KS1 pupils are scored in, for the "on track for KS2" README caveat.
WITH questions AS (
    SELECT
        question_id,
        ANY_VALUE(subject_name) AS subject_name
    FROM `atom-analytics-candidates.de_raw.course_hierarchy`
    GROUP BY question_id
)

SELECT
    question.subject_name,
    CASE
        WHEN sitting.session_id IS NULL THEN '(sitting not found)'
        WHEN sitting.year_group_at_sitting BETWEEN 1 AND 2 THEN 'KS1'
        WHEN sitting.year_group_at_sitting BETWEEN 3 AND 6 THEN 'KS2'
        ELSE 'other'
    END                             AS key_stage_at_score,
    COUNT(*)                        AS n_responses,
    COUNT(DISTINCT resp.pupil_id)   AS n_pupils,
    COUNT(DISTINCT resp.session_id) AS n_sittings
FROM `atom-analytics-candidates.de_raw.responses` AS resp
LEFT JOIN questions AS question ON resp.question_id = question.question_id
LEFT JOIN `atom-analytics-candidates.de_raw.assessment_sittings` AS sitting
    ON resp.session_id = sitting.session_id
GROUP BY 1, 2
ORDER BY 1, 2
