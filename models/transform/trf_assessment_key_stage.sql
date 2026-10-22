-- The key stage each assessment is mainly sat by: count its sittings by the pupil's key stage at
-- the time; the larger wins, and a tie goes to KS2. Sittings outside Years 1-6 aren't counted.
-- Responses are only scored when the pupil's key stage matches the assessment's.
SELECT
    assessment_id,
    COUNTIF(key_stage = 'KS1')                                                AS n_ks1_sittings,
    COUNTIF(key_stage = 'KS2')                                                AS n_ks2_sittings,
    IF(COUNTIF(key_stage = 'KS1') > COUNTIF(key_stage = 'KS2'), 'KS1', 'KS2') AS key_stage
FROM {{ ref('stg_assessment_sittings') }}
WHERE key_stage IS NOT NULL
GROUP BY assessment_id
