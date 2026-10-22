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
        resp.pupil_id,
        question.subject_name,
        COUNT(*) AS n_responses
    FROM `atom-analytics-candidates.de_raw.responses` AS resp
    INNER JOIN `atom-analytics-candidates.de_raw.assessment_sittings` AS sitting
        ON resp.session_id = sitting.session_id
    INNER JOIN questions AS question ON resp.question_id = question.question_id
    WHERE
        NOT COALESCE(sitting.is_deleted, FALSE)
        AND sitting.style IN ('fixed_question', 'non_adaptive')
        AND question.subject_name IN ('Maths', 'English', 'Science')
    GROUP BY resp.pupil_id, question.subject_name
),

pupil_subjects AS (
    SELECT
        pupil.pupil_id,
        subj.subject_name,
        COALESCE(scoped.n_responses, 0) AS n_responses
    FROM pupils AS pupil
    CROSS JOIN subjects AS subj
    LEFT JOIN in_scope AS scoped ON pupil.pupil_id = scoped.pupil_id AND subj.subject_name = scoped.subject_name
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
