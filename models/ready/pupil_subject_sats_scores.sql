-- The app table: one row per pupil × subject they have answered something in, with the score from
-- their latest year group in that subject (the one they were most recently active in). No row = no
-- responses in that subject yet. Maths and English have scaled scores on their key stage's scale
-- (KS1 85-115, KS2 80-120); other subjects only % correct.
SELECT
    pupil_id,
    subject_name,
    key_stage,
    year_group,
    scaled_score,
    percent_correct,
    n_answered,
    n_correct,
    conversion_table_year,
    last_answered_date
FROM {{ ref('pupil_subject_year_scores') }}
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY pupil_id, subject_name
    ORDER BY last_answered_date DESC, year_group DESC
) = 1
