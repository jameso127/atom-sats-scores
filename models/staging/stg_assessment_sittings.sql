-- One row per non-deleted sitting.
SELECT
    session_id,
    style,
    year_group_at_sitting
FROM {{ source('de_raw', 'assessment_sittings') }}
WHERE NOT COALESCE(is_deleted, FALSE)
