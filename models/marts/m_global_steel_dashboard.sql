-- models/marts/m_global_steel_dashboard.sql
{{ config(materialized='table', schema='MARTS') }}

/*
  Purpose: Final dashboard-ready dataset for Power BI / Looker
  Combines:
    - Crude steel forecast (modeled, SWIP, manual)
    - BOF/EAF split
    - Raw material demand
    - Region grouping
  Output: One row per country-year with all key metrics
*/

WITH crude_forecast AS (
  SELECT * FROM {{ ref('fct_crude_steel_forecast') }}
),

bof_eaf AS (
  SELECT * FROM {{ ref('fct_bof_eaf_forecast') }}
),

raw_materials AS (
  SELECT * FROM {{ ref('fct_raw_material_demand') }}
),

-- Define region mapping (can be moved to a dim_country table)
country_region AS (
  SELECT country, 'Asia' AS region FROM (VALUES
    ('China'), ('India'), ('Japan'), ('South Korea'), ('Vietnam'), ('Thailand'), ('Malaysia'), ('Indonesia'), ('Philippines'), ('Singapore'), ('Taiwan')
  ) AS t(country)
  UNION ALL
  SELECT country, 'Europe' AS region FROM (VALUES
    ('Germany'), ('France'), ('Italy'), ('Spain'), ('UK'), ('Netherlands'), ('Belgium'), ('Poland'), ('Sweden'), ('Czech Republic'), ('Austria'), ('Switzerland'), ('Norway'), ('Denmark'), ('Finland'), ('Portugal'), ('Greece'), ('Ireland'), ('Hungary'), ('Romania'), ('Ukraine'), ('Russia'), ('Turkey')
  ) AS t(country)
  UNION ALL
  SELECT country, 'North America' AS region FROM (VALUES
    ('USA'), ('Canada'), ('Mexico')
  ) AS t(country)
  UNION ALL
  SELECT country, 'South America' AS region FROM (VALUES
    ('Brazil'), ('Argentina'), ('Chile'), ('Colombia'), ('Peru')
  ) AS t(country)
  UNION ALL
  SELECT country, 'Middle East & Africa' AS region FROM (VALUES
    ('Saudi Arabia'), ('Iran'), ('UAE'), ('Qatar'), ('Kuwait'), ('Iraq'), ('Egypt'), ('Algeria'), ('South Africa'), ('Kenya'), ('Morocco'), ('Tunisia'), ('Nigeria'), ('Ethiopia'), ('Ghana')
  ) AS t(country)
  UNION ALL
  SELECT country, 'Oceania' AS region FROM (VALUES
    ('Australia'), ('New Zealand')
  ) AS t(country)
  UNION ALL
  SELECT country, 'C.I.S.' AS region FROM (VALUES
    ('Kazakhstan'), ('Azerbaijan'), ('Uzbekistan'), ('Belarus'), ('Armenia'), ('Georgia'), ('Moldova')
  ) AS t(country)
  -- All other countries default to 'Other'
)

SELECT
  cf.country,
  COALESCE(cr.region, 'Other') AS region,
  cf.year,
  cf.crude_steel_tons_thousands,
  be.bof_production,
  be.eaf_production,
  be.eaf_ratio,
  rm.iron_ore_demand_thousands_tons,
  rm.coking_coal_demand_thousands_tons,
  rm.scrap_demand_thousands_tons,
  cf.method AS forecast_method,
  -- Growth metrics
  cf.crude_steel_tons_thousands - LAG(cf.crude_steel_tons_thousands, 1) 
    OVER (PARTITION BY cf.country ORDER BY cf.year) AS year_on_year_change_tons,
  CASE
    WHEN LAG(cf.crude_steel_tons_thousands, 1) OVER (PARTITION BY cf.country ORDER BY cf.year) > 0
    THEN (cf.crude_steel_tons_thousands - LAG(cf.crude_steel_tons_thousands, 1) OVER (PARTITION BY cf.country ORDER BY cf.year))
         / LAG(cf.crude_steel_tons_thousands, 1) OVER (PARTITION BY cf.country ORDER BY cf.year)
    ELSE NULL
  END AS yoy_growth_rate

FROM crude_forecast cf
LEFT JOIN bof_eaf be
  ON cf.country = be.country AND cf.year = be.year
LEFT JOIN raw_materials rm
  ON cf.country = rm.country AND cf.year = rm.year
LEFT JOIN country_region cr
  ON cf.country = cr.country

WHERE cf.year BETWEEN 2003 AND 2033
  AND cf.crude_steel_tons_thousands IS NOT NULL
  AND cf.country IS NOT NULL

ORDER BY cf.country, cf.year