-- models/gold/g_steel_forecast_modeled.sql
{{ config(materialized='table', schema='GLD') }}

/*
  Purpose: Forecast crude steel using analyst-curated OE indicators
  Logic: For each country, apply: crude_steel = slope * indicator_value + intercept
  Source: s_oeused_clean (slope, intercept) + s_oealldata_clean (indicator values)
*/

WITH indicator_values AS (
  SELECT *
  FROM {{ ref('s_oealldata_clean') }}
),

forecast_params AS (
  SELECT 
    country,
    indicator_used,
    slope,
    intercept,
    cagr
  FROM {{ ref('s_oeused_clean') }}
  WHERE primary_indicator = 'OE_INDICATOR'  -- Only use OE where correlation >= 0.7
),

joined AS (
  SELECT 
    iv.country,
    iv.year,
    iv.indicator,
    iv.value AS indicator_value,
    fp.slope,
    fp.intercept,
    fp.cagr,
    (fp.slope * iv.value + fp.intercept) AS crude_steel_tons_thousands
  FROM indicator_values iv
  JOIN forecast_params fp 
    ON iv.country = fp.country 
   AND iv.indicator = fp.indicator_used
  WHERE iv.value IS NOT NULL
)

SELECT 
  country,
  year,
  crude_steel_tons_thousands,
  'OE_MODEL' AS method,
  slope,
  intercept
FROM joined
WHERE crude_steel_tons_thousands IS NOT NULL
  AND year BETWEEN 2003 AND 2033
ORDER BY country, year