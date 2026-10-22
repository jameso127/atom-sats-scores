-- 31 Distribution of current scores
-- Checks: per subject × key stage in the app table, how many pupils, quartiles of the scaled score
-- (Maths / English; KS1 85-115, KS2 80-120), the share meeting the expected standard (>= 100) and
-- average % correct.
-- Why: sanity check of the output before it goes to the app.
SELECT
    subject_name,
    key_stage,
    COUNT(*)                                                                              AS n_pupils,
    APPROX_QUANTILES(scaled_score, 4)                                                     AS scaled_score_quartiles,
    ROUND(COUNTIF(scaled_score >= 100) / NULLIF(COUNTIF(scaled_score IS NOT NULL), 0), 3) AS pct_meeting_expected,
    ROUND(AVG(percent_correct), 1)                                                        AS avg_percent_correct
FROM `atom-analytics-candidates.james_oakley.pupil_subject_sats_scores`
GROUP BY subject_name, key_stage
ORDER BY subject_name, key_stage
