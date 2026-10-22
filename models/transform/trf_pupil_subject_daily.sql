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
    r.pupil_id,
    q.subject_name,
    s.key_stage,
    s.year_group_at_sitting                                                                AS year_group,
    r.answered_date,
    -- Academic year (Sep-Aug): its conversion table is the one STA published the June / July before.
    EXTRACT(YEAR FROM r.answered_date) - IF(EXTRACT(MONTH FROM r.answered_date) < 9, 1, 0) AS academic_year,
    COUNT(*)                                                                               AS n_answered,
    COUNTIF(r.is_correct)                                                                  AS n_correct
FROM {{ ref('stg_responses') }} AS r
INNER JOIN {{ ref('stg_assessment_sittings') }} AS s ON r.session_id = s.session_id
INNER JOIN {{ ref('trf_assessment_key_stage') }} AS a ON s.assessment_id = a.assessment_id
INNER JOIN {{ ref('stg_pupils') }} AS p ON r.pupil_id = p.pupil_id
INNER JOIN {{ ref('stg_course_hierarchy') }} AS q ON r.question_id = q.question_id
WHERE
    s.style IN ('fixed_question', 'non_adaptive')
    AND s.key_stage = a.key_stage
    {% if is_incremental() %}
        AND r.answered_date >= (
            SELECT DATE_SUB(MAX(existing.answered_date), INTERVAL {{ var('lookback_days') }} DAY)
            FROM {{ this }} AS existing
        )
    {% endif %}
GROUP BY r.pupil_id, q.subject_name, s.key_stage, s.year_group_at_sitting, r.answered_date
