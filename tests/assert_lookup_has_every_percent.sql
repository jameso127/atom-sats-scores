-- Every conversion year × scored subject must have all 101 percents (0-100) in the lookup.
SELECT
    test_year,
    subject_name,
    COUNT(*) AS n_percents
FROM {{ ref('trf_percent_to_scaled_score') }}
GROUP BY test_year, subject_name
HAVING COUNT(*) != 101
