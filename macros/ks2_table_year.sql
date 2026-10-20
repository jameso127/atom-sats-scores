{#
    Which KS2 conversion table year applies as at a date: the latest year whose published_date is on
    or before as_at, else the earliest year in the seed (fallback for dates before the first table).
    var('conversion_table_year') overrides it. Returns a SQL expression.

    as_at: a SQL date expression, e.g. date('2025-09-01').
#}
{% macro ks2_table_year(as_at) -%}
    {%- if var('conversion_table_year', none) is not none -%}
        {{ var('conversion_table_year') | int }}
    {%- else -%}
        (
            select coalesce(
                max(case when published_date <= {{ as_at }} then test_year end),
                min(test_year)
            )
            from {{ ref('seed_ks2_scaled_score_conversion') }}
        )
    {%- endif -%}
{%- endmacro %}
