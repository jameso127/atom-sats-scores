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
        resp.pupil_id,
        question.subject_name
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

per_pupil AS (
    SELECT
        pupil.pupil_id,
        COUNT(pupil_subj.subject_name)                                                                  AS n_subjects,
        COALESCE(STRING_AGG(pupil_subj.subject_name, ' + ' ORDER BY pupil_subj.subject_name), '(none)') AS subjects
    FROM pupils AS pupil
    LEFT JOIN pupil_subjects AS pupil_subj ON pupil.pupil_id = pupil_subj.pupil_id
    GROUP BY pupil.pupil_id
)

SELECT
    n_subjects,
    subjects,
    COUNT(*) AS n_pupils
FROM per_pupil
GROUP BY n_subjects, subjects
ORDER BY n_subjects, subjects
