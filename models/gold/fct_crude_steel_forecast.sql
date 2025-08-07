-- models/gold/fct_crude_steel_forecast.sql
{{ config(materialized='table', schema='GLD') }}

WITH manual_overrides AS (
  -- Use the actual table you created
  SELECT 
    country,
    year,
    crude_steel_tons_thousands,
    'manual_override' AS method
  FROM ANALYST_OVERRIDES.CRUDLE_STEEL_MANUAL
  WHERE crude_steel_tons_thousands IS NOT NULL
),

modeled_forecast AS (
  -- Forecast from OE indicators (e.g., Production index)
  SELECT 
    country,
    year,
    crude_steel_tons_thousands,
    'modeled' AS method
  FROM {{ ref('g_steel_forecast_modeled') }}
),

swip_forecast AS (
  -- Fallback: SWIP-based forecast
  SELECT 
    country,
    year,
    crude_steel_tons_thousands,
    'swip_fallback' AS method
  FROM {{ ref('g_steel_forecast_swip') }}
),

-- Combine: Manual overrides take precedence
unioned AS (
  -- 1. Start with manual overrides
  SELECT * FROM manual_overrides
  
  UNION ALL
  
  -- 2. Add modeled forecast where no manual override
  SELECT * FROM modeled_forecast
  WHERE (country, year) NOT IN (
    SELECT country, year FROM manual_overrides
  )
  
  UNION ALL
  
  -- 3. Add SWIP where neither manual nor modeled exists
  SELECT * FROM swip_forecast
  WHERE (country, year) NOT IN (
    SELECT country, year FROM manual_overrides
    UNION ALL
    SELECT country, year FROM modeled_forecast
  )
)

SELECT 
  country,
  year,
  crude_steel_tons_thousands,
  method
FROM unioned
WHERE crude_steel_tons_thousands IS NOT NULL
  AND year BETWEEN 2003 AND 2033
ORDER BY country, year