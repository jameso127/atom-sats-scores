-- 22 Which sittings have responses
-- Checks: by style × session_type × is_complete, how many sittings have responses and which subjects.
-- Why: 14 shows no adaptive or non_adaptive sittings with responses; confirms which styles and
-- session types actually contribute data.
WITH questions AS (
    SELECT
        question_id,
        ANY_VALUE(subject_name) AS subject_name
    FROM `atom-analytics-candidates.de_raw.course_hierarchy`
    GROUP BY question_id
),

sitting_responses AS (
    SELECT
        resp.session_id,
        COUNT(*)                                                                         AS n_responses,
        STRING_AGG(DISTINCT question.subject_name, ' + ' ORDER BY question.subject_name) AS subjects
    FROM `atom-analytics-candidates.de_raw.responses` AS resp
    LEFT JOIN questions AS question ON resp.question_id = question.question_id
    GROUP BY resp.session_id
)

SELECT
    sitting.style,
    sitting.session_type,
    sitting.is_complete,
    sit_resp.subjects,
    COUNT(*)                               AS n_sittings,
    COUNTIF(sit_resp.session_id IS NULL)   AS n_without_responses,
    SUM(COALESCE(sit_resp.n_responses, 0)) AS n_responses
FROM `atom-analytics-candidates.de_raw.assessment_sittings` AS sitting
LEFT JOIN sitting_responses AS sit_resp ON sitting.session_id = sit_resp.session_id
GROUP BY 1, 2, 3, 4
ORDER BY 1, 2, 3, 4
