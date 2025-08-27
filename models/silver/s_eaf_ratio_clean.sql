{{
  config(
    materialized='view',
    schema='fast_market_transform_silver'
  )
}}

with base as (
  select
    "Data", 
    "Location", 
    "Indicator", 
    "Sector", 
    "Units", 
    "Scale", 
    "Measurement",
    {% for year in range(1995, 2034) %}
    to_varchar("Y{{ year }}") as "Y{{ year }}"{% if not loop.last %},{% endif %}
    {% endfor %}
  from {{ source('bronze', 'raw_oe_alldata') }}
),

kv as (
  select
    "Location" as country,
    "Indicator" as indicator,
    "Sector" as sector,
    "Units" as units,
    f.key::string as year_label,
    f.value::string as value_raw
  from (
    select
      *,
      object_construct(
        {% for year in range(1995, 2034) %}
        'Y{{ year }}', "Y{{ year }}"{% if not loop.last %},{% endif %}
        {% endfor %}
      ) as ymap
    from base
  ) b,
  lateral flatten(input => b.ymap) f
)

select
  country,
  indicator,
  sector,
  units,
  substring(year_label, 2)::int as year,
  try_to_numeric(regexp_replace(value_raw, '[, ]', '')) as value
from kv