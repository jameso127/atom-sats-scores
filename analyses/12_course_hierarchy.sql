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
    ch.subject_name,
    COUNT(DISTINCT ch.subject_id)                                                AS n_subject_ids,
    COUNT(*)                                                                     AS n_rows,
    COUNT(DISTINCT ch.question_id)                                               AS n_questions,
    COUNT(DISTINCT ch.atom_id)                                                   AS n_atoms,
    COUNT(DISTINCT ch.subtopic_id)                                               AS n_subtopics,
    COUNT(DISTINCT ch.topic_id)                                                  AS n_topics,
    COUNT(DISTINCT IF(qs.n_subjects > 1, ch.question_id, NULL))                  AS n_questions_in_multiple_subjects,
    COUNTIF(ch.atom_id IS NULL OR ch.subtopic_id IS NULL OR ch.topic_id IS NULL) AS n_rows_missing_level
FROM `atom-analytics-candidates.de_raw.course_hierarchy` AS ch
LEFT JOIN question_subjects AS qs ON ch.question_id = qs.question_id
GROUP BY ch.subject_name
ORDER BY ch.subject_name
