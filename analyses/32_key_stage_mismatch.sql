-- 32 Responses removed by the key-stage match
-- Checks: each assessment's key stage (most sittings, tie = KS2), then how many in-scope-style
-- responses come from pupils whose key stage at the sitting differs from the assessment's, by
-- direction and subject.
-- Why: sizes the rule that a KS1 pupil's KS2 assessment (or the reverse) isn't scored.
WITH sittings AS (
    SELECT
        session_id,
        assessment_id,
        style,
        IF(year_group_at_sitting <= 2, 'KS1', 'KS2') AS key_stage
    FROM `atom-analytics-candidates.de_raw.assessment_sittings`
    WHERE NOT COALESCE(is_deleted, FALSE) AND year_group_at_sitting BETWEEN 1 AND 6
),

assessments AS (
    SELECT
        assessment_id,
        COUNTIF(key_stage = 'KS1')                                                AS n_ks1_sittings,
        COUNTIF(key_stage = 'KS2')                                                AS n_ks2_sittings,
        IF(COUNTIF(key_stage = 'KS1') > COUNTIF(key_stage = 'KS2'), 'KS1', 'KS2') AS key_stage
    FROM sittings
    GROUP BY assessment_id
),

questions AS (
    SELECT
        question_id,
        ANY_VALUE(subject_name) AS subject_name
    FROM `atom-analytics-candidates.de_raw.course_hierarchy`
    GROUP BY question_id
)

SELECT
    assess.key_stage                                           AS assessment_key_stage,
    sitting.key_stage                                          AS pupil_key_stage,
    question.subject_name,
    sitting.key_stage = assess.key_stage                       AS is_scored,
    COUNT(*)                                                   AS n_responses,
    COUNT(DISTINCT resp.pupil_id)                              AS n_pupils,
    COUNT(DISTINCT sitting.session_id)                         AS n_sittings,
    COUNT(DISTINCT assess.assessment_id)                       AS n_assessments,
    COUNTIF(assess.n_ks1_sittings = assess.n_ks2_sittings) > 0 AS has_tied_assessment
FROM `atom-analytics-candidates.de_raw.responses` AS resp
INNER JOIN sittings AS sitting ON resp.session_id = sitting.session_id
INNER JOIN assessments AS assess ON sitting.assessment_id = assess.assessment_id
INNER JOIN questions AS question ON resp.question_id = question.question_id
WHERE sitting.style IN ('fixed_question', 'non_adaptive')
GROUP BY 1, 2, 3, 4
ORDER BY 1, 2, 3
