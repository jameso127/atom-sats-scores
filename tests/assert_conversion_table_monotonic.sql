-- A higher raw mark must never give a lower scaled score; a failure means a transcription error.
with ordered as (
    select
        test_year,
        ks2_test,
        raw_score,
        scaled_score,
        lag(scaled_score) over (
            partition by test_year, ks2_test order by raw_score
        ) as previous_scaled_score
    from {{ ref('seed_ks2_scaled_score_conversion') }}
)

select *
from ordered
where scaled_score < previous_scaled_score
