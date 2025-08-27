{{ config(schema='silver', materialized='view') }}

with base as (
  {{ unpivot_monthly(
       source('bronze','raw_oe_selected'),
       id_cols=["series_id","country","unit"] 
     )
  }}
)
select
  upper(country) as country,
  series_id,
  unit,
  month_start,
  value::float as value,
  'raw_oe_selected' as source_table
from base
where month_start is not null;
