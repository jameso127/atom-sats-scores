{#
    Point-in-time filter for history tables with valid_from / valid_to (valid_to null = current).
    Selects the row in force on date d. Use this rather than re-writing the condition.

    d: a SQL date expression, e.g. date('2025-09-01').
#}
{% macro as_at_filter(d, valid_from='valid_from', valid_to='valid_to') -%}
    ({{ valid_from }} <= {{ d }} and ({{ valid_to }} > {{ d }} or {{ valid_to }} is null))
{%- endmacro %}
