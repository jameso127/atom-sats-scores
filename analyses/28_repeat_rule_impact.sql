-- 28 Effect of collapsing repeated question rows
-- Checks: % correct per scored subject (in-scope responses only) under four rules for repeated
-- pupil × sitting × question rows: keep all rows, max (correct if any row correct), mean
-- (fractional credit), min (correct only if every row correct).
-- Why: sizes the scoring impact of the repeated-rows decision (see 21, 25-27).
WITH questions AS (
    SELECT
        question_id,
        ANY_VALUE(subject_name) AS subject_name
    FROM `atom-analytics-candidates.de_raw.course_hierarchy`
    GROUP BY question_id
),

per_question AS (
    SELECT
        question.subject_name,
        resp.pupil_id,
        COUNT(*)                 AS n_rows,
        COUNTIF(resp.is_correct) AS n_correct_rows
    FROM `atom-analytics-candidates.de_raw.responses` AS resp
    INNER JOIN `atom-analytics-candidates.de_raw.assessment_sittings` AS sitting
        ON resp.session_id = sitting.session_id
    INNER JOIN questions AS question ON resp.question_id = question.question_id
    WHERE
        NOT COALESCE(sitting.is_deleted, FALSE)
        AND sitting.style IN ('fixed_question', 'non_adaptive')
        AND question.subject_name IN ('Maths', 'English')
    GROUP BY question.subject_name, resp.pupil_id, resp.session_id, resp.question_id
),

per_pupil AS (
    SELECT
        subject_name,
        pupil_id,
        SUM(n_correct_rows) / SUM(n_rows)           AS pct_keep_all,
        COUNTIF(n_correct_rows > 0) / COUNT(*)      AS pct_max,
        SUM(n_correct_rows / n_rows) / COUNT(*)     AS pct_mean,
        COUNTIF(n_correct_rows = n_rows) / COUNT(*) AS pct_min
    FROM per_question
    GROUP BY subject_name, pupil_id
)

SELECT
    subject_name,
    COUNT(*)                                     AS n_pupils,
    ROUND(AVG(pct_keep_all), 4)                  AS avg_pct_keep_all,
    ROUND(AVG(pct_max), 4)                       AS avg_pct_max,
    ROUND(AVG(pct_mean), 4)                      AS avg_pct_mean,
    ROUND(AVG(pct_min), 4)                       AS avg_pct_min,
    ROUND(MAX(pct_max - pct_keep_all), 4)        AS max_pupil_gain_max_vs_keep_all,
    COUNTIF(ABS(pct_max - pct_keep_all) >= 0.02) AS n_pupils_moved_2pts_by_max
FROM per_pupil
GROUP BY subject_name
ORDER BY subject_name
