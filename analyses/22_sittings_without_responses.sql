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
        r.session_id,
        COUNT(*)                                                           AS n_responses,
        STRING_AGG(DISTINCT q.subject_name, ' + ' ORDER BY q.subject_name) AS subjects
    FROM `atom-analytics-candidates.de_raw.responses` AS r
    LEFT JOIN questions AS q ON r.question_id = q.question_id
    GROUP BY r.session_id
)

SELECT
    s.style,
    s.session_type,
    s.is_complete,
    sr.subjects,
    COUNT(*)                         AS n_sittings,
    COUNTIF(sr.session_id IS NULL)   AS n_without_responses,
    SUM(COALESCE(sr.n_responses, 0)) AS n_responses
FROM `atom-analytics-candidates.de_raw.assessment_sittings` AS s
LEFT JOIN sitting_responses AS sr ON s.session_id = sr.session_id
GROUP BY 1, 2, 3, 4
ORDER BY 1, 2, 3, 4
