-- One row per pupil × subject × year group: all the pupil's in-scope responses from sittings in
-- that year group added up into one % correct, up to the as-at date (var('as_at'), default
-- everything). Maths and English then look up their scaled score from that % correct; other
-- subjects have no lookup rows, so their scaled score stays null.
WITH totals AS (
    SELECT
        pupil_id,
        subject_name,
        year_group,
        SUM(n_answered)    AS n_answered,
        SUM(n_correct)     AS n_correct,
        MAX(answered_date) AS last_answered_date
    FROM {{ ref('trf_pupil_subject_daily') }}
    {% if var('as_at') %}
        WHERE answered_date <= DATE('{{ var("as_at") }}')
    {% endif %}
    GROUP BY pupil_id, subject_name, year_group
)

SELECT
    t.pupil_id,
    t.subject_name,
    t.year_group,
    t.n_answered,
    t.n_correct,
    100 * t.n_correct / t.n_answered AS percent_correct,
    s.scaled_score,
    s.test_year                      AS conversion_table_year,
    t.last_answered_date
FROM totals AS t
LEFT JOIN {{ ref('trf_percent_to_scaled_score') }} AS s
    ON s.subject_name = t.subject_name
    -- The conversion table for the academic year (Sep-Aug) of the latest response; STA publishes
    -- each year's table in July, before the academic year it's used for.
    AND s.test_year = EXTRACT(YEAR FROM t.last_answered_date) - IF(EXTRACT(MONTH FROM t.last_answered_date) < 9, 1, 0)
    -- % correct rounded down to a whole percent.
    AND s.percent_correct = DIV(100 * t.n_correct, t.n_answered)
