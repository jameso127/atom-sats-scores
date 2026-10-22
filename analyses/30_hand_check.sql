-- 30 Hand check of the scoring
-- Checks: recomputes the current score straight from de_raw, independently of the models, for the
-- most active KS1 and KS2 pupil in each subject (scored on their latest year group only), and puts
-- the model's answer alongside.
-- Why: verifies the scope rules (including the key-stage match with the assessment), the % correct,
-- the whole-percent equivalent raw mark, the key stage and academic-year table choice, the
-- conversion lookup and the English blend end to end.
WITH sittings AS (
    SELECT
        session_id,
        assessment_id,
        style,
        year_group_at_sitting,
        IF(year_group_at_sitting <= 2, 'KS1', 'KS2') AS key_stage
    FROM `atom-analytics-candidates.de_raw.assessment_sittings`
    WHERE NOT COALESCE(is_deleted, FALSE) AND year_group_at_sitting BETWEEN 1 AND 6
),

-- The key stage each assessment is mainly sat by (tie = KS2).
assessments AS (
    SELECT
        assessment_id,
        IF(COUNTIF(key_stage = 'KS1') > COUNTIF(key_stage = 'KS2'), 'KS1', 'KS2') AS key_stage
    FROM sittings
    GROUP BY assessment_id
),

in_scope AS (
    SELECT
        resp.pupil_id,
        hier.subject_name,
        resp.is_correct,
        sitting.year_group_at_sitting,
        sitting.key_stage,
        resp.answered_at
    FROM `atom-analytics-candidates.de_raw.responses` AS resp
    INNER JOIN sittings AS sitting ON resp.session_id = sitting.session_id
    INNER JOIN assessments AS assess ON sitting.assessment_id = assess.assessment_id
    INNER JOIN `atom-analytics-candidates.de_raw.course_hierarchy` AS hier
        ON resp.question_id = hier.question_id
    WHERE
        sitting.style IN ('fixed_question', 'non_adaptive')
        AND sitting.key_stage = assess.key_stage
        AND hier.subject_name IN ('Maths', 'English')
),

-- Totals per pupil × subject × year group, keeping each pupil's latest year group.
totals AS (
    SELECT
        pupil_id,
        subject_name,
        year_group_at_sitting  AS last_year_group,
        ANY_VALUE(key_stage)   AS key_stage,
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
        key_stage,
        n_answered,
        n_correct,
        EXTRACT(YEAR FROM last_date) - IF(EXTRACT(MONTH FROM last_date) < 9, 1, 0) AS table_year
    FROM totals
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY subject_name, key_stage
        ORDER BY n_answered DESC, pupil_id ASC
    ) = 1
),

conversion AS (
    SELECT
        key_stage,
        test_year,
        test_name,
        raw_score,
        scaled_score,
        max_raw_score,
        min_scaled_score
    FROM `atom-analytics-candidates.james_oakley.stg_scaled_score_conversion`
),

tests AS (
    SELECT
        'Maths' AS subject_name,
        'maths' AS test_name,
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
        pick.pupil_id,
        pick.subject_name,
        ANY_VALUE(pick.key_stage)       AS key_stage,
        ANY_VALUE(pick.last_year_group) AS last_year_group,
        ANY_VALUE(pick.n_answered)      AS n_answered,
        ANY_VALUE(pick.n_correct)       AS n_correct,
        ANY_VALUE(pick.table_year)      AS table_year,
        STRING_AGG(
            test.test_name || ' raw ' || CAST(DIV(DIV(100 * pick.n_correct, pick.n_answered) * conv.max_raw_score, 100) AS STRING)
            || ' -> ' || CAST(conv.scaled_score AS STRING), '; ' ORDER BY test.test_name
        )                               AS working,
        CAST(ROUND(SUM(test.weight * COALESCE(conv.scaled_score, conv.min_scaled_score)) / SUM(test.weight)) AS INT64)
            AS scaled_by_hand
    FROM picked AS pick
    INNER JOIN tests AS test ON pick.subject_name = test.subject_name
    INNER JOIN conversion AS conv
        ON
            pick.key_stage = conv.key_stage
            AND pick.table_year = conv.test_year
            AND test.test_name = conv.test_name
            -- Whole percent (rounded down), then equivalent raw mark, as in trf_percent_to_scaled_score.
            AND DIV(DIV(100 * pick.n_correct, pick.n_answered) * conv.max_raw_score, 100) = conv.raw_score
    GROUP BY pick.pupil_id, pick.subject_name
)

SELECT
    hand.subject_name,
    hand.key_stage,
    hand.last_year_group,
    hand.n_answered,
    hand.n_correct,
    ROUND(hand.n_correct / hand.n_answered, 4) AS pct_correct,
    hand.table_year,
    hand.working,
    hand.scaled_by_hand,
    built.scaled_score                         AS scaled_by_model,
    built.n_answered                           AS n_answered_by_model,
    built.conversion_table_year                AS table_year_by_model,
    hand.scaled_by_hand = built.scaled_score   AS is_match
FROM by_hand AS hand
LEFT JOIN `atom-analytics-candidates.james_oakley.pupil_subject_year_scores` AS built
    ON
        hand.pupil_id = built.pupil_id
        AND hand.subject_name = built.subject_name
        AND hand.last_year_group = built.year_group
ORDER BY hand.subject_name, hand.key_stage
