-- 15 Key stages used by each assessment
-- Checks: for each assessment, which key stages its sittings were taken at, grouped into
-- combinations (KS1 only, KS2 only, both, other).
-- Why: records the already-profiled counts (29 KS1-only / 69 KS2-only / 13 shared / 1 no year
-- group) that justify taking key stage from the sitting rather than the assessment.
WITH sittings AS (
    SELECT
        assessment_id,
        CASE
            WHEN year_group_at_sitting BETWEEN 1 AND 2 THEN 'KS1'
            WHEN year_group_at_sitting BETWEEN 3 AND 6 THEN 'KS2'
            ELSE 'other'
        END AS key_stage
    FROM `atom-analytics-candidates.de_raw.assessment_sittings`
),

assessments AS (
    SELECT
        assessment_id,
        STRING_AGG(DISTINCT key_stage, ' + ' ORDER BY key_stage) AS key_stages,
        COUNT(*)                                                 AS n_sittings
    FROM sittings
    GROUP BY assessment_id
)

SELECT
    key_stages,
    COUNT(*)        AS n_assessments,
    SUM(n_sittings) AS n_sittings
FROM assessments
GROUP BY key_stages
ORDER BY key_stages
