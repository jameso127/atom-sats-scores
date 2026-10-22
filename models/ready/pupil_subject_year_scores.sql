-- One row per pupil × subject × year group: all the pupil's in-scope responses from sittings in
-- that year group added up into one % correct, up to the as-at date (var('as_at'), default
-- everything). Maths and English then look up their scaled score on the scale for the key stage
-- they were in (KS1 85-115, KS2 80-120); other subjects have no lookup rows, so stay null.
WITH totals AS (
    SELECT
        pupil_id,
        subject_name,
        key_stage,
        year_group,
        SUM(n_answered)    AS n_answered,
        SUM(n_correct)     AS n_correct,
        MAX(answered_date) AS last_answered_date,
        -- The academic year of the latest response picks the conversion table.
        MAX(academic_year) AS academic_year
    FROM {{ ref('trf_pupil_subject_daily') }}
    {% if var('as_at') %}
        WHERE answered_date <= DATE('{{ var("as_at") }}')
    {% endif %}
    GROUP BY pupil_id, subject_name, key_stage, year_group
)

SELECT
    total.pupil_id,
    total.subject_name,
    total.key_stage,
    total.year_group,
    total.n_answered,
    total.n_correct,
    100 * total.n_correct / total.n_answered AS percent_correct,
    pct_lookup.scaled_score,
    pct_lookup.test_year                     AS conversion_table_year,
    total.last_answered_date
FROM totals AS total
LEFT JOIN {{ ref('trf_percent_to_scaled_score') }} AS pct_lookup
    ON
        total.key_stage = pct_lookup.key_stage
        AND total.academic_year = pct_lookup.test_year
        AND total.subject_name = pct_lookup.subject_name
        -- % correct rounded down to a whole percent.
        AND DIV(100 * total.n_correct, total.n_answered) = pct_lookup.percent_correct
