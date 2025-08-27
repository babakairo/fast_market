{{ config(schema='silver', materialized='view') }}

with base as (
  {{ unpivot_monthly(source('bronze','raw_oe_used')) }}
)
select
  *
  , 'raw_oe_used' as source_table
from base
where month_start is not null;
