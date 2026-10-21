-- 13 Responses by subject
-- Checks: per subject, response / pupil / sitting volume, is_correct null rate, skip rate and raw
-- % correct. Responses with no matching question show as '(no question match)'.
-- Why: confirms the Wellbeing / Screeners exclusions (expect null is_correct) and sizes each subject.
WITH questions AS (
    SELECT
        question_id,
        ANY_VALUE(subject_name) AS subject_name
    FROM `atom-analytics-candidates.de_raw.course_hierarchy`
    GROUP BY question_id
)

SELECT
    COALESCE(q.subject_name, '(no question match)')                                AS subject_name,
    COUNT(*)                                                                       AS n_responses,
    COUNT(DISTINCT r.pupil_id)                                                     AS n_pupils,
    COUNT(DISTINCT r.session_id)                                                   AS n_sittings,
    COUNTIF(r.is_correct IS NULL)                                                  AS n_is_correct_null,
    ROUND(COUNTIF(r.is_correct IS NULL) / COUNT(*), 4)                             AS pct_is_correct_null,
    ROUND(COUNTIF(r.is_no_attempt) / COUNT(*), 4)                                  AS pct_no_attempt,
    ROUND(COUNTIF(r.is_correct) / NULLIF(COUNTIF(r.is_correct IS NOT NULL), 0), 4) AS pct_correct
FROM `atom-analytics-candidates.de_raw.responses` AS r
LEFT JOIN questions AS q ON r.question_id = q.question_id
GROUP BY 1
ORDER BY n_responses DESC
