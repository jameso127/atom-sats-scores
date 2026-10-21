-- 30 Hand check of the scoring
-- Checks: recomputes the current score straight from de_raw, independently of the models, for the
-- most active KS1 and KS2 pupil in each subject (scored on their latest year group only), and puts
-- the model's answer alongside.
-- Why: verifies the scope rules, the % correct, the whole-percent equivalent raw mark, the
-- academic-year table choice, the conversion lookup and the English blend end to end.
WITH in_scope AS (
    SELECT
        r.pupil_id,
        ch.subject_name,
        r.is_correct,
        s.year_group_at_sitting,
        r.answered_at
    FROM `atom-analytics-candidates.de_raw.responses` AS r
    INNER JOIN `atom-analytics-candidates.de_raw.assessment_sittings` AS s
        ON r.session_id = s.session_id
    INNER JOIN `atom-analytics-candidates.de_raw.course_hierarchy` AS ch
        ON r.question_id = ch.question_id
    WHERE
        NOT COALESCE(s.is_deleted, FALSE)
        AND s.style IN ('fixed_question', 'non_adaptive')
        AND ch.subject_name IN ('Maths', 'English')
),

-- Totals per pupil × subject × year group, keeping each pupil's latest year group.
totals AS (
    SELECT
        pupil_id,
        subject_name,
        year_group_at_sitting  AS last_year_group,
        COUNT(*)               AS n_answered,
        COUNTIF(is_correct)    AS n_correct,
        MAX(DATE(answered_at)) AS last_date
    FROM in_scope
    GROUP BY pupil_id, subject_name, year_group_at_sitting
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY pupil_id, subject_name
        ORDER BY MAX(DATE(answered_at)) DESC, year_group_at_sitting DESC
    ) = 1
),

picked AS (
    SELECT
        pupil_id,
        subject_name,
        last_year_group,
        n_answered,
        n_correct,
        last_date
    FROM totals
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY subject_name, last_year_group <= 2
        ORDER BY n_answered DESC, pupil_id ASC
    ) = 1
),

with_year AS (
    SELECT
        p.pupil_id,
        p.subject_name,
        p.last_year_group,
        p.n_answered,
        p.n_correct,
        p.last_date,
        EXTRACT(YEAR FROM p.last_date) - IF(EXTRACT(MONTH FROM p.last_date) < 9, 1, 0) AS table_year
    FROM picked AS p
),

conversion AS (
    SELECT
        test_year,
        ks2_test,
        raw_score,
        scaled_score,
        max_raw_score
    FROM `atom-analytics-candidates.james_oakley.stg_ks2_scaled_score_conversion`
),

tests AS (
    SELECT
        'Maths' AS subject_name,
        'maths' AS ks2_test,
        1.0     AS weight
    UNION ALL
    SELECT
        'English',
        'reading',
        0.5
    UNION ALL
    SELECT
        'English',
        'gps',
        0.5
),

by_hand AS (
    SELECT
        w.pupil_id,
        w.subject_name,
        ANY_VALUE(w.n_answered)                                                            AS n_answered,
        ANY_VALUE(w.n_correct)                                                             AS n_correct,
        ANY_VALUE(w.table_year)                                                            AS table_year,
        ANY_VALUE(w.last_year_group)                                                       AS last_year_group,
        STRING_AGG(
            t.ks2_test || ' raw ' || CAST(DIV(DIV(100 * w.n_correct, w.n_answered) * c.max_raw_score, 100) AS STRING)
            || ' -> ' || CAST(c.scaled_score AS STRING), '; ' ORDER BY t.ks2_test
        )                                                                                  AS working,
        CAST(ROUND(SUM(t.weight * COALESCE(c.scaled_score, 80)) / SUM(t.weight)) AS INT64) AS scaled_by_hand
    FROM with_year AS w
    INNER JOIN tests AS t ON w.subject_name = t.subject_name
    INNER JOIN conversion AS c
        ON
            w.table_year = c.test_year
            AND c.ks2_test = t.ks2_test
            -- Whole percent (rounded down), then equivalent raw mark, as in trf_percent_to_scaled_score.
            AND c.raw_score = DIV(DIV(100 * w.n_correct, w.n_answered) * c.max_raw_score, 100)
    GROUP BY w.pupil_id, w.subject_name
)

SELECT
    h.subject_name,
    h.last_year_group,
    h.n_answered,
    h.n_correct,
    ROUND(h.n_correct / h.n_answered, 4) AS pct_correct,
    h.table_year,
    h.working,
    h.scaled_by_hand,
    m.scaled_score                       AS scaled_by_model,
    m.n_answered                         AS n_answered_by_model,
    m.conversion_table_year              AS table_year_by_model,
    h.scaled_by_hand = m.scaled_score    AS is_match
FROM by_hand AS h
LEFT JOIN `atom-analytics-candidates.james_oakley.pupil_subject_year_scores` AS m
    ON
        h.pupil_id = m.pupil_id
        AND h.subject_name = m.subject_name
        AND h.last_year_group = m.year_group
ORDER BY h.subject_name, h.last_year_group
