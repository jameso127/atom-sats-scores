-- One row per question and the subject it belongs to.
SELECT
    question_id,
    subject_name
FROM {{ source('de_raw', 'course_hierarchy') }}
