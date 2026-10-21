-- 29 Output checksums
-- Checks: row count and an order-independent checksum of every built model's contents.
-- Why: the re-run check; a second (incremental) build and a --full-refresh must give identical
-- numbers.
SELECT
    'trf_pupil_subject_daily'                    AS model_name,
    COUNT(*)                                     AS n_rows,
    BIT_XOR(FARM_FINGERPRINT(TO_JSON_STRING(t))) AS checksum
FROM `atom-analytics-candidates.james_oakley.trf_pupil_subject_daily` AS t
UNION ALL
SELECT
    'pupil_subject_year_scores',
    COUNT(*),
    BIT_XOR(FARM_FINGERPRINT(TO_JSON_STRING(t)))
FROM `atom-analytics-candidates.james_oakley.pupil_subject_year_scores` AS t
UNION ALL
SELECT
    'pupil_subject_sats_scores',
    COUNT(*),
    BIT_XOR(FARM_FINGERPRINT(TO_JSON_STRING(t)))
FROM `atom-analytics-candidates.james_oakley.pupil_subject_sats_scores` AS t
ORDER BY model_name
