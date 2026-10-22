-- 23 Sittings with year group outside 1-6
-- Checks: for year groups 11 / 14 / 15 (see 07), the assessments, subjects, session types and the
-- same pupils' other year groups.
-- Why: decides whether these are real (e.g. older siblings, staff tests) or data errors, and
-- whether they stay in scope labelled 'other'.
WITH questions AS (
    SELECT
        question_id,
        ANY_VALUE(subject_name) AS subject_name
    FROM `atom-analytics-candidates.de_raw.course_hierarchy`
    GROUP BY question_id
),

odd AS (
    SELECT
        session_id,
        pupil_id,
        assessment_id,
        session_type,
        style,
        year_group_at_sitting
    FROM `atom-analytics-candidates.de_raw.assessment_sittings`
    WHERE year_group_at_sitting NOT BETWEEN 1 AND 6 OR year_group_at_sitting IS NULL
),

o AS (SELECT DISTINCT pupil_id FROM odd),

pupil_other_year_groups AS (
    SELECT
        sitting.pupil_id,
        STRING_AGG(DISTINCT CAST(sitting.year_group_at_sitting AS STRING), ', ') AS other_year_groups
    FROM `atom-analytics-candidates.de_raw.assessment_sittings` AS sitting
    INNER JOIN o ON sitting.pupil_id = odd_sit.pupil_id
    WHERE sitting.year_group_at_sitting BETWEEN 1 AND 6
    GROUP BY sitting.pupil_id
),

odd_subjects AS (
    SELECT
        resp.session_id,
        STRING_AGG(DISTINCT question.subject_name, ' + ') AS subjects,
        COUNT(*)                                          AS n_responses
    FROM `atom-analytics-candidates.de_raw.responses` AS resp
    INNER JOIN odd AS odd_sit ON resp.session_id = odd_sit.session_id
    LEFT JOIN questions AS question ON resp.question_id = question.question_id
    GROUP BY resp.session_id
)

SELECT
    odd_sit.year_group_at_sitting,
    odd_sit.assessment_id,
    odd_sit.style,
    odd_sit.session_type,
    odd_subj.subjects,
    COALESCE(other_yg.other_year_groups, '(none)') AS pupil_other_year_groups,
    COUNT(*)                                       AS n_sittings,
    COUNT(DISTINCT odd_sit.pupil_id)               AS n_pupils,
    SUM(COALESCE(odd_subj.n_responses, 0))         AS n_responses
FROM odd AS odd_sit
LEFT JOIN odd_subjects AS odd_subj ON odd_sit.session_id = odd_subj.session_id
LEFT JOIN pupil_other_year_groups AS other_yg ON odd_sit.pupil_id = other_yg.pupil_id
GROUP BY 1, 2, 3, 4, 5, 6
ORDER BY 1, 2
