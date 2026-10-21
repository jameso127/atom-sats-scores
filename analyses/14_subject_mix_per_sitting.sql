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
        r.session_id,
        COALESCE(q.subject_name, '(no question match)') AS subject_name
    FROM `atom-analytics-candidates.de_raw.responses` AS r
    LEFT JOIN questions AS q ON r.question_id = q.question_id
),

sitting_subjects AS (
    SELECT
        session_id,
        STRING_AGG(DISTINCT subject_name, ' + ' ORDER BY subject_name) AS subjects
    FROM response_subjects
    GROUP BY session_id
)

SELECT
    s.style,
    ss.subjects,
    COUNT(*) AS n_sittings
FROM sitting_subjects AS ss
LEFT JOIN `atom-analytics-candidates.de_raw.assessment_sittings` AS s
    ON ss.session_id = s.session_id
GROUP BY s.style, ss.subjects
ORDER BY s.style ASC, n_sittings DESC
