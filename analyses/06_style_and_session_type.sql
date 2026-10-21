-- 06 Sitting style and session_type values
-- Checks: every style × session_type combination, with deleted and complete counts.
-- Why: confirms the style scope rule (6 adaptive sittings already profiled) and settles the open
-- decision on which session_type values count.
SELECT
    style,
    session_type,
    COUNT(*)                      AS n_sittings,
    COUNT(DISTINCT pupil_id)      AS n_pupils,
    COUNT(DISTINCT assessment_id) AS n_assessments,
    COUNTIF(is_deleted)           AS n_deleted,
    COUNTIF(is_complete)          AS n_complete
FROM `atom-analytics-candidates.de_raw.assessment_sittings`
GROUP BY style, session_type
ORDER BY style, session_type
