-- 14 Subjects within a sitting
-- Checks: for each style, the combinations of subjects that appear within one sitting.
-- Why: shows whether Screener (or other) sittings mix in questions from scored subjects, and
-- confirms no adaptive sittings contain scored subjects.
WITH questions AS (
    SELECT
        question_id,
        ANY_VALUE(subject_name) AS subject_name
    FROM `atom-analytics-candidates.de_raw.course_hierarchy`
    GROUP BY question_id
),

response_subjects AS (
    SELECT
        resp.session_id,
        COALESCE(question.subject_name, '(no question match)') AS subject_name
    FROM `atom-analytics-candidates.de_raw.responses` AS resp
    LEFT JOIN questions AS question ON resp.question_id = question.question_id
),

sitting_subjects AS (
    SELECT
        session_id,
        STRING_AGG(DISTINCT subject_name, ' + ' ORDER BY subject_name) AS subjects
    FROM response_subjects
    GROUP BY session_id
)

SELECT
    sitting.style,
    sit_subj.subjects,
    COUNT(*) AS n_sittings
FROM sitting_subjects AS sit_subj
LEFT JOIN `atom-analytics-candidates.de_raw.assessment_sittings` AS sitting
    ON sit_subj.session_id = sitting.session_id
GROUP BY sitting.style, sit_subj.subjects
ORDER BY sitting.style ASC, n_sittings DESC
