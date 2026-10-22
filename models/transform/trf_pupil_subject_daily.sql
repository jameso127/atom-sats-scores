{{
    config(
        materialized='incremental',
        incremental_strategy='insert_overwrite',
        partition_by={'field': 'answered_date', 'data_type': 'date'},
        cluster_by=['pupil_id', 'subject_name']
    )
}}

-- Answered and correct counts per pupil × subject × year group × day, for in-scope responses
-- only: the sitting exists and isn't deleted, the pupil isn't deleted, the style is scored (which
-- leaves out Wellbeing surveys), and the pupil's key stage at the time matches the key stage the
-- assessment is mainly sat by (so a KS1 pupil's KS2 assessment, or the reverse, isn't scored).
-- Every subject is kept; only Maths and English get a scaled score later. Incremental runs
-- recompute the last var('lookback_days') days and replace those whole day partitions.
SELECT
    resp.pupil_id,
    question.subject_name,
    sitting.key_stage,
    sitting.year_group_at_sitting                                                                AS year_group,
    resp.answered_date,
    -- Academic year (Sep-Aug): its conversion table is the one STA published the June / July before.
    EXTRACT(YEAR FROM resp.answered_date) - IF(EXTRACT(MONTH FROM resp.answered_date) < 9, 1, 0) AS academic_year,
    COUNT(*)                                                                                     AS n_answered,
    COUNTIF(resp.is_correct)                                                                     AS n_correct
FROM {{ ref('stg_responses') }} AS resp
INNER JOIN {{ ref('stg_assessment_sittings') }} AS sitting ON resp.session_id = sitting.session_id
INNER JOIN {{ ref('trf_assessment_key_stage') }} AS assess ON sitting.assessment_id = assess.assessment_id
INNER JOIN {{ ref('stg_pupils') }} AS pupil ON resp.pupil_id = pupil.pupil_id
INNER JOIN {{ ref('stg_course_hierarchy') }} AS question ON resp.question_id = question.question_id
WHERE
    sitting.style IN ('fixed_question', 'non_adaptive')
    AND sitting.key_stage = assess.key_stage
    {% if is_incremental() %}
        -- _dbt_max_partition: the table's latest answered_date, declared by dbt for insert_overwrite.
        AND resp.answered_date >= DATE_SUB(_dbt_max_partition, INTERVAL {{ var('lookback_days') }} DAY)  -- noqa: RF02
    {% endif %}
GROUP BY resp.pupil_id, question.subject_name, sitting.key_stage, sitting.year_group_at_sitting, resp.answered_date
