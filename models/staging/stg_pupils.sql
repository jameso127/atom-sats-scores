-- One row per non-deleted pupil.
SELECT pupil_id
FROM {{ source('de_raw', 'pupils') }}
WHERE NOT COALESCE(is_deleted, FALSE)
