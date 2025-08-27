{{ config(schema='silver', materialized='view') }}

select
  -- rename/clean to the canonical shape
  series_id,
  upper(country) as country,
  unit,
  to_date(month_start) as month_start,
  try_to_number(value) as value,
  'raw_oe_monthly' as source_table
from {{ source('bronze','raw_oe_monthly') }}
where month_start is not null;
