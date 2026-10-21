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
        s.pupil_id,
        STRING_AGG(DISTINCT CAST(s.year_group_at_sitting AS STRING), ', ') AS other_year_groups
    FROM `atom-analytics-candidates.de_raw.assessment_sittings` AS s
    INNER JOIN o ON s.pupil_id = o.pupil_id
    WHERE s.year_group_at_sitting BETWEEN 1 AND 6
    GROUP BY s.pupil_id
),

odd_subjects AS (
    SELECT
        r.session_id,
        STRING_AGG(DISTINCT q.subject_name, ' + ') AS subjects,
        COUNT(*)                                   AS n_responses
    FROM `atom-analytics-candidates.de_raw.responses` AS r
    INNER JOIN odd AS o ON r.session_id = o.session_id
    LEFT JOIN questions AS q ON r.question_id = q.question_id
    GROUP BY r.session_id
)

SELECT
    o.year_group_at_sitting,
    o.assessment_id,
    o.style,
    o.session_type,
    os.subjects,
    COALESCE(p.other_year_groups, '(none)') AS pupil_other_year_groups,
    COUNT(*)                                AS n_sittings,
    COUNT(DISTINCT o.pupil_id)              AS n_pupils,
    SUM(COALESCE(os.n_responses, 0))        AS n_responses
FROM odd AS o
LEFT JOIN odd_subjects AS os ON o.session_id = os.session_id
LEFT JOIN pupil_other_year_groups AS p ON o.pupil_id = p.pupil_id
GROUP BY 1, 2, 3, 4, 5, 6
ORDER BY 1, 2
