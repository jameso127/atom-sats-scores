-- 10 Activity by month and academic year
-- Checks: responses, pupils and sittings per month, labelled with the academic year (Sep-Aug) and
-- the conversion table year ks2_table_year() would pick (clamped to the 2024-2026 seeds).
-- Why: sets the default as_at and shows whether pre-2024 tables are needed.
SELECT
    DATE_TRUNC(DATE(answered_at), MONTH)                                           AS answered_month,
    EXTRACT(YEAR FROM answered_at) - IF(EXTRACT(MONTH FROM answered_at) < 9, 1, 0) AS academic_year_start,
    GREATEST(2024, LEAST(
        2026,
        EXTRACT(YEAR FROM answered_at) - IF(EXTRACT(MONTH FROM answered_at) < 9, 1, 0)
    ))                                                                             AS conversion_table_year,
    COUNT(*)                                                                       AS n_responses,
    COUNT(DISTINCT pupil_id)                                                       AS n_pupils,
    COUNT(DISTINCT session_id)                                                     AS n_sittings
FROM `atom-analytics-candidates.de_raw.responses`
GROUP BY 1, 2, 3
ORDER BY 1
