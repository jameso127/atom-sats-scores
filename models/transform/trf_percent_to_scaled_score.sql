-- Lookup from % correct (a whole percent, 0-100) to scaled score, per key stage, conversion year
-- and subject. For each percent: equivalent raw mark on each test the subject maps to =
-- floor(percent × full marks / 100), then its official scaled score, averaged by the subject's
-- weights (English = half reading, half GPS). Raw marks 0-2 have no official score, so they count
-- as the bottom of the scale (KS1 85, KS2 80).
WITH percents AS (
    SELECT percent_correct FROM UNNEST(GENERATE_ARRAY(0, 100)) AS percent_correct
)

SELECT
    conv.key_stage,
    conv.test_year,
    mapping.subject_name,
    perc.percent_correct,
    CAST(ROUND(SUM(mapping.weight * COALESCE(conv.scaled_score, conv.min_scaled_score))) AS INT64) AS scaled_score
FROM {{ ref('seed_subject_to_test') }} AS mapping
INNER JOIN {{ ref('stg_scaled_score_conversion') }} AS conv ON mapping.test_name = conv.test_name
INNER JOIN percents AS perc ON conv.raw_score = DIV(perc.percent_correct * conv.max_raw_score, 100)
GROUP BY conv.key_stage, conv.test_year, mapping.subject_name, perc.percent_correct
