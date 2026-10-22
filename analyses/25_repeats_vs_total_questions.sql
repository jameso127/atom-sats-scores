-- 25 Repeated question rows vs total_questions
-- Checks: in sittings with and without repeated question rows, whether total_questions equals the
-- number of distinct questions or the number of rows.
-- Why: if total_questions counts distinct questions, the extra rows are duplicates; if it counts
-- rows, each row is a mark on a multi-mark question.
WITH question_rows AS (
    SELECT
        session_id,
        question_id,
        COUNT(*) AS n_rows
    FROM `atom-analytics-candidates.de_raw.responses`
    GROUP BY session_id, question_id
),

sitting_rows AS (
    SELECT
        session_id,
        SUM(n_rows)         AS n_rows,
        COUNT(*)            AS n_questions,
        COUNTIF(n_rows > 1) AS n_repeated_questions
    FROM question_rows
    GROUP BY session_id
)

SELECT
    sit_rows.n_repeated_questions > 0  AS has_repeats,
    CASE
        WHEN sitting.total_questions = sit_rows.n_questions AND sitting.total_questions = sit_rows.n_rows THEN 'total = questions = rows'
        WHEN sitting.total_questions = sit_rows.n_questions THEN 'total = distinct questions'
        WHEN sitting.total_questions = sit_rows.n_rows THEN 'total = rows'
        WHEN sitting.total_questions > sit_rows.n_rows THEN 'total > rows (incomplete)'
        ELSE 'other'
    END                                AS total_questions_matches,
    COUNT(*)                           AS n_sittings,
    SUM(sit_rows.n_rows)               AS n_rows,
    SUM(sit_rows.n_repeated_questions) AS n_repeated_questions
FROM sitting_rows AS sit_rows
INNER JOIN `atom-analytics-candidates.de_raw.assessment_sittings` AS sitting
    ON sit_rows.session_id = sitting.session_id
GROUP BY 1, 2
ORDER BY 1, 2
