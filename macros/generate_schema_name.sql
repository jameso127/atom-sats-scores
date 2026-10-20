{#
    Everything (models, seeds, snapshots) lands in the target dataset (james_oakley), because that is
    the dataset reviewers were told to look at. dbt's default would create james_oakley_<custom>.
    Layers are separated by model-name prefix (stg_, int_, fct_) instead.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {{ target.schema }}
{%- endmacro %}
