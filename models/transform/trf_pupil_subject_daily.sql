{{
    config(
        materialized='incremental',
        incremental_strategy='insert_overwrite',
        partition_by={'field': 'answered_date', 'data_type': 'date'},
        cluster_by=['pupil_id', 'subject_name']
    )
}}

-- Answered and correct counts per pupil × subject × year group × day, for in-scope responses
-- only: the sitting exists and isn't deleted, the pupil isn't deleted and the style is scored
-- (which leaves out Wellbeing surveys). Every subject is kept; only Maths and English get a
-- scaled score later. Incremental runs recompute the last var('lookback_days') days and replace
-- those whole day partitions.
SELECT
    r.pupil_id,
    q.subject_name,
    s.year_group_at_sitting AS year_group,
    r.answered_date,
    COUNT(*)                AS n_answered,
    COUNTIF(r.is_correct)   AS n_correct
FROM {{ ref('stg_responses') }} AS r
INNER JOIN {{ ref('stg_assessment_sittings') }} AS s ON r.session_id = s.session_id
INNER JOIN {{ ref('stg_pupils') }} AS p ON r.pupil_id = p.pupil_id
INNER JOIN {{ ref('stg_course_hierarchy') }} AS q ON r.question_id = q.question_id
WHERE
    s.style IN ('fixed_question', 'non_adaptive')
    {% if is_incremental() %}
        AND r.answered_date >= (
            SELECT DATE_SUB(MAX(existing.answered_date), INTERVAL {{ var('lookback_days') }} DAY)
            FROM {{ this }} AS existing
        )
    {% endif %}
GROUP BY r.pupil_id, q.subject_name, s.year_group_at_sitting, r.answered_date
