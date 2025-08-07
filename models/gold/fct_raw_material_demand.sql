-- models/gold/fct_raw_material_demand.sql
{{ config(materialized='table', schema='GLD') }}

/*
  Purpose: Calculate raw material demand based on BOF and EAF production
  Source: fct_bof_eaf_forecast (which comes from fct_crude_steel_forecast + EAF ratios)
  Logic:
    - BOF (Basic Oxygen Furnace) uses iron ore and coking coal
    - EAF (Electric Arc Furnace) uses scrap metal
  Assumptions (industry standards):
    - 1.6 tonnes of iron ore per tonne of BOF steel
    - 0.8 tonnes of coking coal per tonne of BOF steel
    - 1.1 tonnes of scrap per tonne of EAF steel
*/

WITH bof_eaf AS (
  SELECT
    country,
    year,
    bof_production AS bof_steel_thousands_tons,
    eaf_production AS eaf_steel_thousands_tons
  FROM {{ ref('fct_bof_eaf_forecast') }}
  WHERE year BETWEEN 2003 AND 2033
),

-- Apply material intensity factors
raw_materials AS (
  SELECT
    country,
    year,
    -- BOF inputs
    bof_steel_thousands_tons,
    bof_steel_thousands_tons * 1.6 AS iron_ore_demand_thousands_tons,   -- 1.6x
    bof_steel_thousands_tons * 0.8 AS coking_coal_demand_thousands_tons, -- 0.8x
    -- EAF inputs
    eaf_steel_thousands_tons,
    eaf_steel_thousands_tons * 1.1 AS scrap_demand_thousands_tons,       -- 1.1x
    -- Total crude steel
    (bof_steel_thousands_tons + eaf_steel_thousands_tons) AS total_crude_steel_thousands_tons
  FROM bof_eaf
)

SELECT
  country,
  year,
  total_crude_steel_thousands_tons,
  iron_ore_demand_thousands_tons,
  coking_coal_demand_thousands_tons,
  scrap_demand_thousands_tons,
  'calculated' AS method
FROM raw_materials
WHERE country IS NOT NULL
  AND year IS NOT NULL
  AND (iron_ore_demand_thousands_tons > 0 OR scrap_demand_thousands_tons > 0)
ORDER BY country, year