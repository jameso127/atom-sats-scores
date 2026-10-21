-- Every conversion year must have all three KS2 tests, or English / Science lookups would drop rows.
WITH tests_per_year AS (
    SELECT
        test_year,
        COUNT(DISTINCT ks2_test) AS n_tests
    FROM {{ ref('stg_ks2_scaled_score_conversion') }}
    GROUP BY test_year
)

SELECT
    test_year,
    n_tests
FROM tests_per_year
WHERE n_tests != 3
