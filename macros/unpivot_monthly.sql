{% macro unpivot_monthly(relation, id_cols=[], month_regex="(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)-\\d{4}|\\d{4}-\\d{2}|\\d{4}") %}
  {# Inspect columns #}
  {% set cols = adapter.get_columns_in_relation(relation) %}
  {% set id_list = [] %}
  {% set month_list = [] %}

  {% for c in cols %}
    {% if c.name is regex_match(month_regex, ignorecase=True) %}
      {% do month_list.append( adapter.quote(c.name) ) %}
    {% else %}
      {% if c.name|lower not in ['_load_ts','ingested_at','src_file','src_sheet','row_hash'] %}
        {% do id_list.append( adapter.quote(c.name) ) %}
      {% endif %}
    {% endif %}
  {% endfor %}

  with src as (
    select * from {{ relation }}
  ),
  u as (
    select
      {% if id_cols|length > 0 %}
        {{ id_cols | join(', ') }},
      {% else %}
        {{ id_list | join(', ') }},
      {% endif %}
      month_label,
      try_to_number(value) as value
    from src
    unpivot(value for month_label in ({{ month_list | join(', ') }})) unp
  )
  select
    {{ (id_cols if id_cols|length>0 else id_list) | join(', ') }},
    coalesce(
      try_to_date(month_label,'MON-YYYY'),
      try_to_date(month_label,'YYYY-MM'),
      to_date(month_label)  -- handles YYYY
    ) as month_start,
    value
  from u
  where value is not null
{% endmacro %}
