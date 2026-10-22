-- Every Maths / English year score must have a scaled score. Fails if its academic year has no
-- conversion table in the seeds (e.g. a new academic year starts before its table is added).
SELECT
    pupil_id,
    subject_name,
    year_group,
    last_answered_date
FROM {{ ref('pupil_subject_year_scores') }}
WHERE
    subject_name IN (SELECT m.subject_name FROM {{ ref('seed_subject_to_test') }} AS m)
    AND scaled_score IS NULL
