-- Each scored subject's KS2 test weights must sum to 1, or its scaled score is not a true average.
WITH weights AS (
    SELECT
        subject_name,
        SUM(weight) AS total_weight
    FROM {{ ref('seed_subject_to_test') }}
    GROUP BY subject_name
)

SELECT
    subject_name,
    total_weight
FROM weights
WHERE ABS(total_weight - 1) > 0.000001
