-- One row per non-deleted sitting, with the pupil's key stage at the time (from their year group).
SELECT
    session_id,
    assessment_id,
    style,
    year_group_at_sitting,
    CASE
        WHEN year_group_at_sitting BETWEEN 1 AND 2 THEN 'KS1'
        WHEN year_group_at_sitting BETWEEN 3 AND 6 THEN 'KS2'
    END AS key_stage
FROM {{ source('de_raw', 'assessment_sittings') }}
WHERE NOT COALESCE(is_deleted, FALSE)
