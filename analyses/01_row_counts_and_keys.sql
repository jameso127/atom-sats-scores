-- 01 Row counts and primary keys
-- Checks: rows, distinct and null values of each table's assumed primary key.
-- Why: every model's grain depends on these keys being unique and non-null.
SELECT
    'responses'                  AS table_name,
    COUNT(*)                     AS n_rows,
    COUNT(DISTINCT response_id)  AS n_distinct_key,
    COUNTIF(response_id IS NULL) AS n_null_key
FROM `atom-analytics-candidates.de_raw.responses`
UNION ALL
SELECT
    'assessment_sittings',
    COUNT(*),
    COUNT(DISTINCT session_id),
    COUNTIF(session_id IS NULL)
FROM `atom-analytics-candidates.de_raw.assessment_sittings`
UNION ALL
SELECT
    'pupils',
    COUNT(*),
    COUNT(DISTINCT pupil_id),
    COUNTIF(pupil_id IS NULL)
FROM `atom-analytics-candidates.de_raw.pupils`
UNION ALL
SELECT
    'course_hierarchy',
    COUNT(*),
    COUNT(DISTINCT question_id),
    COUNTIF(question_id IS NULL)
FROM `atom-analytics-candidates.de_raw.course_hierarchy`
