-- 11 Re-attempts of the same question
-- Checks: how many times each pupil answers the same question, and across how many sittings
-- (capped at 10 to keep the output short).
-- Why: settles whether every response counts or only the first / latest per question.
WITH pupil_questions AS (
    SELECT
        pupil_id,
        question_id,
        COUNT(*)                   AS n_attempts,
        COUNT(DISTINCT session_id) AS n_sittings
    FROM `atom-analytics-candidates.de_raw.responses`
    GROUP BY pupil_id, question_id
)

SELECT
    LEAST(n_attempts, 10) AS n_attempts_capped,
    LEAST(n_sittings, 10) AS n_sittings_capped,
    COUNT(*)              AS n_pupil_questions
FROM pupil_questions
GROUP BY 1, 2
ORDER BY 1, 2
