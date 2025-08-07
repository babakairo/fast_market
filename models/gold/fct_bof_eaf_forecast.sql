-- models/gold/fct_bof_eaf_forecast.sql
{{ config(materialized='table', schema='GLD') }}

WITH final_forecast AS (
  SELECT * FROM {{ ref('fct_crude_steel_forecast') }}
),

eaf_ratios AS (
  SELECT country, year, eaf_ratio
  FROM {{ ref('s_eaf_ratio_clean') }}
)

SELECT
  f.country,
  f.year,
  f.crude_steel_tons_thousands,
  f.crude_steel_tons_thousands * (1 - COALESCE(e.eaf_ratio, 0)) AS bof_production,
  f.crude_steel_tons_thousands * COALESCE(e.eaf_ratio, 0) AS eaf_production,
  COALESCE(e.eaf_ratio, 0) AS eaf_ratio
FROM final_forecast f
LEFT JOIN eaf_ratios e ON f.country = e.country AND f.year = e.year
ORDER BY f.country, f.year