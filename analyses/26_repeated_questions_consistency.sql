-- 26 Is repetition a property of the question?
-- Checks: for each question that is ever repeated within a sitting, whether it is repeated in
-- every sitting it appears in, and with the same number of rows each time.
-- Why: a multi-mark question would always produce the same number of rows; duplicate events would
-- hit questions at random.
WITH questions AS (
    SELECT
        question_id,
        ANY_VALUE(subject_name) AS subject_name
    FROM `atom-analytics-candidates.de_raw.course_hierarchy`
    GROUP BY question_id
),

question_rows AS (
    SELECT
        session_id,
        question_id,
        COUNT(*) AS n_rows
    FROM `atom-analytics-candidates.de_raw.responses`
    GROUP BY session_id, question_id
),

per_question AS (
    SELECT
        question_id,
        COUNT(*)            AS n_sittings,
        COUNTIF(n_rows > 1) AS n_sittings_repeated,
        MIN(n_rows)         AS min_rows,
        MAX(n_rows)         AS max_rows
    FROM question_rows
    GROUP BY question_id
    HAVING COUNTIF(n_rows > 1) > 0
)

SELECT
    question.subject_name,
    CASE
        WHEN per_q.n_sittings = 1 THEN 'seen in only one sitting'
        WHEN per_q.n_sittings_repeated = per_q.n_sittings AND per_q.min_rows = per_q.max_rows
            THEN 'same row count in every sitting'
        WHEN per_q.n_sittings_repeated = per_q.n_sittings THEN 'repeated in every sitting, varying count'
        ELSE 'repeated in some sittings only'
    END                            AS pattern,
    COUNT(*)                       AS n_questions,
    SUM(per_q.n_sittings)          AS n_sittings_answered,
    SUM(per_q.n_sittings_repeated) AS n_sittings_repeated
FROM per_question AS per_q
LEFT JOIN questions AS question ON per_q.question_id = question.question_id
GROUP BY 1, 2
ORDER BY 1, 2
