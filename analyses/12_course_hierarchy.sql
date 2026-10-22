-- 12 Course hierarchy shape
-- Checks: per subject, questions / atoms / subtopics / topics, subject_id <-> subject_name
-- consistency, and questions that appear under more than one subject.
-- Why: subject comes from this table, so a question in two subjects would double-count it.
WITH question_subjects AS (
    SELECT
        question_id,
        COUNT(DISTINCT subject_name) AS n_subjects
    FROM `atom-analytics-candidates.de_raw.course_hierarchy`
    GROUP BY question_id
)

SELECT
    hier.subject_name,
    COUNT(DISTINCT hier.subject_id)                                                    AS n_subject_ids,
    COUNT(*)                                                                           AS n_rows,
    COUNT(DISTINCT hier.question_id)                                                   AS n_questions,
    COUNT(DISTINCT hier.atom_id)                                                       AS n_atoms,
    COUNT(DISTINCT hier.subtopic_id)                                                   AS n_subtopics,
    COUNT(DISTINCT hier.topic_id)                                                      AS n_topics,
    COUNT(DISTINCT IF(subj_count.n_subjects > 1, hier.question_id, NULL))              AS n_questions_in_multiple_subjects,
    COUNTIF(hier.atom_id IS NULL OR hier.subtopic_id IS NULL OR hier.topic_id IS NULL) AS n_rows_missing_level
FROM `atom-analytics-candidates.de_raw.course_hierarchy` AS hier
LEFT JOIN question_subjects AS subj_count ON hier.question_id = subj_count.question_id
GROUP BY hier.subject_name
ORDER BY hier.subject_name
