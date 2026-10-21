-- One row per question a pupil answered. Repeated rows for the same question in a sitting are
-- kept (FINDINGS 21, 25-28). responses.session_type isn't used: it's always 'MOCK_TEST'.
-- A view: trf_pupil_subject_daily (incremental) filters it to recent days.
SELECT
    response_id,
    pupil_id,
    session_id,
    question_id,
    is_correct,
    answered_at,
    DATE(answered_at) AS answered_date
FROM {{ source('de_raw', 'responses') }}
