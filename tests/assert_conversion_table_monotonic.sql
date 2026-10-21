-- A higher raw mark must never give a lower scaled score; a failure means a transcription error.
WITH ordered AS (
    SELECT
        test_year,
        ks2_test,
        raw_score,
        scaled_score,
        LAG(scaled_score) OVER (
            PARTITION BY test_year, ks2_test ORDER BY raw_score
        ) AS previous_scaled_score
    FROM {{ ref('stg_ks2_scaled_score_conversion') }}
)

SELECT
    test_year,
    ks2_test,
    raw_score,
    scaled_score,
    previous_scaled_score
FROM ordered
WHERE scaled_score < previous_scaled_score
