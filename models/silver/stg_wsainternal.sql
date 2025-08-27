{{ config(schema='silver', materialized='view') }}

-- Map the generic c1,c2,... to meaningful names once you know them
select
  c1::string  as series_id,
  upper(c2)::string as country,
  c3::string  as unit,
  try_to_number(c4) as value,
  to_date(c5) as month_start,
  'raw_wsainternal' as source_table
from {{ source('bronze','raw_wsainternal') }}
where month_start is not null;
