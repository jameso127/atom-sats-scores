-- Lookup from % correct (a whole percent, 0-100) to KS2 scaled score, per conversion year and
-- subject. For each percent: equivalent raw mark on each KS2 test the subject maps to =
-- floor(percent × full marks / 100), then its official scaled score, averaged by the subject's
-- weights (English = half reading, half GPS). Raw marks 0-2 have no official score, so count as 80.
WITH percents AS (
    SELECT percent_correct FROM UNNEST(GENERATE_ARRAY(0, 100)) AS percent_correct
)

SELECT
    c.test_year,
    m.subject_name,
    p.percent_correct,
    CAST(ROUND(SUM(m.weight * COALESCE(c.scaled_score, 80))) AS INT64) AS scaled_score
FROM {{ ref('seed_subject_to_ks2_test') }} AS m
INNER JOIN {{ ref('stg_ks2_scaled_score_conversion') }} AS c ON m.ks2_test = c.ks2_test
INNER JOIN percents AS p ON c.raw_score = DIV(p.percent_correct * c.max_raw_score, 100)
GROUP BY c.test_year, m.subject_name, p.percent_correct
