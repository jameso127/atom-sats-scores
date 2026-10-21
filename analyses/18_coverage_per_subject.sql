-- 18 Coverage per pupil × scored subject
-- Checks: for every non-deleted pupil × scored subject, how many in-scope responses they have:
-- pupils with none, a bucketed distribution, and deciles among pupils with any.
-- Why: sizes the has_responses = false rows (and was used to consider a low-confidence threshold,
-- since dropped). Science was in scope when run and later removed; it has no responses.
WITH pupils AS (
    SELECT pupil_id
    FROM `atom-analytics-candidates.de_raw.pupils`
    GROUP BY pupil_id
    HAVING NOT LOGICAL_OR(COALESCE(is_deleted, FALSE))
),

subjects AS (
    SELECT subject_name FROM UNNEST(['Maths', 'English', 'Science']) AS subject_name
),

questions AS (
    SELECT
        question_id,
        ANY_VALUE(subject_name) AS subject_name
    FROM `atom-analytics-candidates.de_raw.course_hierarchy`
    GROUP BY question_id
),

in_scope AS (
    SELECT
        r.pupil_id,
        q.subject_name,
        COUNT(*) AS n_responses
    FROM `atom-analytics-candidates.de_raw.responses` AS r
    INNER JOIN `atom-analytics-candidates.de_raw.assessment_sittings` AS s
        ON r.session_id = s.session_id
    INNER JOIN questions AS q ON r.question_id = q.question_id
    WHERE
        NOT COALESCE(s.is_deleted, FALSE)
        AND s.style IN ('fixed_question', 'non_adaptive')
        AND q.subject_name IN ('Maths', 'English', 'Science')
    GROUP BY r.pupil_id, q.subject_name
),

pupil_subjects AS (
    SELECT
        p.pupil_id,
        sub.subject_name,
        COALESCE(i.n_responses, 0) AS n_responses
    FROM pupils AS p
    CROSS JOIN subjects AS sub
    LEFT JOIN in_scope AS i ON p.pupil_id = i.pupil_id AND sub.subject_name = i.subject_name
)

SELECT
    subject_name,
    COUNT(*)                                                     AS n_pupils,
    COUNTIF(n_responses = 0)                                     AS n_no_responses,
    COUNTIF(n_responses BETWEEN 1 AND 9)                         AS n_1_to_9,
    COUNTIF(n_responses BETWEEN 10 AND 19)                       AS n_10_to_19,
    COUNTIF(n_responses BETWEEN 20 AND 49)                       AS n_20_to_49,
    COUNTIF(n_responses BETWEEN 50 AND 99)                       AS n_50_to_99,
    COUNTIF(n_responses BETWEEN 100 AND 199)                     AS n_100_to_199,
    COUNTIF(n_responses >= 200)                                  AS n_200_plus,
    APPROX_QUANTILES(IF(n_responses > 0, n_responses, NULL), 10) AS deciles_when_any
FROM pupil_subjects
GROUP BY subject_name
ORDER BY subject_name
