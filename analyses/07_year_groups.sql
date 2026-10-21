-- 07 Year group values
-- Checks: every year_group_at_sitting value and the key stage label it gets.
-- Why: identifies the ~25 sittings labelled 'other' (null or outside Years 1-6) for the README.
SELECT
    year_group_at_sitting,
    CASE
        WHEN year_group_at_sitting BETWEEN 1 AND 2 THEN 'KS1'
        WHEN year_group_at_sitting BETWEEN 3 AND 6 THEN 'KS2'
        ELSE 'other'
    END                      AS key_stage_at_score,
    COUNT(*)                 AS n_sittings,
    COUNT(DISTINCT pupil_id) AS n_pupils,
    COUNTIF(is_deleted)      AS n_deleted
FROM `atom-analytics-candidates.de_raw.assessment_sittings`
GROUP BY year_group_at_sitting
ORDER BY year_group_at_sitting
