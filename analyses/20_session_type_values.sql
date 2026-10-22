-- 20 session_type on responses vs sittings
-- Checks: the value pairs behind 04's mismatch (every joined response disagreed with its sitting).
-- Why: decides which column session_type comes from, and which values count as in scope.
SELECT
    resp.session_type               AS response_session_type,
    sitting.session_type            AS sitting_session_type,
    sitting.style,
    COUNT(*)                        AS n_responses,
    COUNT(DISTINCT resp.session_id) AS n_sittings
FROM `atom-analytics-candidates.de_raw.responses` AS resp
LEFT JOIN `atom-analytics-candidates.de_raw.assessment_sittings` AS sitting
    ON resp.session_id = sitting.session_id
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3
