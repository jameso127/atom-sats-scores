-- 08 is_correct vs is_no_attempt
-- Checks: every combination of the two flags, including nulls.
-- Why: confirms skipped questions can be counted as answered and wrong, and whether is_correct is
-- null or false when skipped (or ever true).
SELECT
    is_correct,
    is_no_attempt,
    COUNT(*) AS n_responses
FROM `atom-analytics-candidates.de_raw.responses`
GROUP BY is_correct, is_no_attempt
ORDER BY is_correct, is_no_attempt
