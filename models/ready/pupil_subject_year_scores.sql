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
    t.pupil_id,
    t.subject_name,
    t.key_stage,
    t.year_group,
    t.n_answered,
    t.n_correct,
    100 * t.n_correct / t.n_answered AS percent_correct,
    s.scaled_score,
    s.test_year                      AS conversion_table_year,
    t.last_answered_date
FROM totals AS t
LEFT JOIN {{ ref('trf_percent_to_scaled_score') }} AS s
    ON
        t.key_stage = s.key_stage
        AND t.academic_year = s.test_year
        AND t.subject_name = s.subject_name
        -- % correct rounded down to a whole percent.
        AND DIV(100 * t.n_correct, t.n_answered) = s.percent_correct
