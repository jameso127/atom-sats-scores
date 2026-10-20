-- Every conversion year must have all three KS2 tests, or English / Science lookups would drop rows.
with tests_per_year as (
    select test_year, count(distinct ks2_test) as n_tests
    from {{ ref('seed_ks2_scaled_score_conversion') }}
    group by test_year
)

select *
from tests_per_year
where n_tests != 3
