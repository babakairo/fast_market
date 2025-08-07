-- models/gold/g_steel_forecast_swip.sql
{{ config(materialized='table', schema='GLD') }}

/*
  Purpose: Use SWIP index where OE correlation < 0.7
  Source: s_oeused_clean (SWIP flag) + future SWIP index logic
*/

SELECT 
  country,
  2023 AS year,
  1000 AS crude_steel_tons_thousands,  -- Placeholder
  'SWIP' AS method
FROM {{ ref('s_oeused_clean') }}
WHERE swip_flag = 'SWIP'