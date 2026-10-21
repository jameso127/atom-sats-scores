-- 19 Scored subjects per pupil
-- Checks: how many non-deleted pupils have in-scope responses in 0, 1, 2 or 3 scored subjects,
-- and which combinations.
-- Why: "every pupil in every subject" means some output rows will have no responses; this sizes it.
WITH pupils AS (
    SELECT pupil_id
    FROM `atom-analytics-candidates.de_raw.pupils`
    GROUP BY pupil_id
    HAVING NOT LOGICAL_OR(COALESCE(is_deleted, FALSE))
),

questions AS (
    SELECT
        question_id,
        ANY_VALUE(subject_name) AS subject_name
    FROM `atom-analytics-candidates.de_raw.course_hierarchy`
    GROUP BY question_id
),

pupil_subjects AS (
    SELECT
        r.pupil_id,
        q.subject_name
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

per_pupil AS (
    SELECT
        p.pupil_id,
        COUNT(ps.subject_name)                                                          AS n_subjects,
        COALESCE(STRING_AGG(ps.subject_name, ' + ' ORDER BY ps.subject_name), '(none)') AS subjects
    FROM pupils AS p
    LEFT JOIN pupil_subjects AS ps ON p.pupil_id = ps.pupil_id
    GROUP BY p.pupil_id
)

SELECT
    n_subjects,
    subjects,
    COUNT(*) AS n_pupils
FROM per_pupil
GROUP BY n_subjects, subjects
ORDER BY n_subjects, subjects
