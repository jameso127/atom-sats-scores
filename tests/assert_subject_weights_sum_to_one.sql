-- Each scored subject's KS2 test weights must sum to 1, or its scaled score is not a true average.
with weights as (
    select subject_name, sum(weight) as total_weight
    from {{ ref('seed_subject_to_ks2_test') }}
    group by subject_name
)

select *
from weights
where abs(total_weight - 1) > 0.000001
