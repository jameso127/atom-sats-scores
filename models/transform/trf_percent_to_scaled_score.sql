-- Lookup from % correct (a whole percent, 0-100) to scaled score, per key stage, conversion year
-- and subject. For each percent: equivalent raw mark on each test the subject maps to =
-- floor(percent × full marks / 100), then its official scaled score, averaged by the subject's
-- weights (English = half reading, half GPS). Raw marks 0-2 have no official score, so they count
-- as the bottom of the scale (KS1 85, KS2 80).
WITH percents AS (
    SELECT percent_correct FROM UNNEST(GENERATE_ARRAY(0, 100)) AS percent_correct
)

SELECT
    c.key_stage,
    c.test_year,
    m.subject_name,
    p.percent_correct,
    CAST(ROUND(SUM(m.weight * COALESCE(c.scaled_score, c.min_scaled_score))) AS INT64) AS scaled_score
FROM {{ ref('seed_subject_to_test') }} AS m
INNER JOIN {{ ref('stg_scaled_score_conversion') }} AS c ON m.test_name = c.test_name
INNER JOIN percents AS p ON c.raw_score = DIV(p.percent_correct * c.max_raw_score, 100)
GROUP BY c.key_stage, c.test_year, m.subject_name, p.percent_correct
