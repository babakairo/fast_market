-- models/silver/s_oealldata_clean.sql
{{ config(materialized='table', schema='SLV') }}

WITH raw AS (
  SELECT 
    "Location" AS country,
    "Indicator" AS indicator,
    "Sector" AS sector,
    "Nace code" AS nace_code_raw,
    "Source" AS source,
    "Contact email" AS contact_email,
    -- Build array of year values
    ARRAY_CONSTRUCT(
      "Y1995", "Y1996", "Y1997", "Y1998", "Y1999",
      "Y2000", "Y2001", "Y2002", "Y2003", "Y2004",
      "Y2005", "Y2006", "Y2007", "Y2008", "Y2009",
      "Y2010", "Y2011", "Y2012", "Y2013", "Y2014",
      "Y2015", "Y2016", "Y2017", "Y2018", "Y2019",
      "Y2020", "Y2021", "Y2022", "Y2023", "Y2024",
      "Y2025", "Y2026", "Y2027", "Y2028", "Y2029",
      "Y2030", "Y2031", "Y2032", "Y2033"
    ) AS year_values
  FROM {{ source('raw', 'OEALLDATA') }}
  WHERE "Location" IS NOT NULL
    AND "Location" != ''
    AND "Location" NOT LIKE '||%'
    AND "Location" NOT LIKE '%ID#%'
    AND "Location" NOT LIKE '%=====%'
    AND "Location" NOT LIKE '%#%'
    AND "Location" NOT IN ('Total - World', 'WSA and file calculation match', 'Manufacturing')
),

flattened AS (
  SELECT 
    -- Extract country: before any special characters
    SPLIT_PART(TRIM(country), ':', 1) AS country,
    indicator,
    SPLIT_PART(TRIM(sector), ',', 1) AS sector,
    REGEXP_SUBSTR(nace_code_raw, '\\d+\\.?\\d*')::NUMBER AS nace_code,
    source,
    contact_email,
    1994 + SEQ4() AS year,
    VALUE AS value_raw
  FROM raw,
  LATERAL FLATTEN(input => year_values)
)

SELECT 
  country,
  indicator,
  sector,
  nace_code,
  source,
  contact_email,
  year,
  CASE
    WHEN value_raw IN ('#REF!', '#NAME?', '#ERROR!', '', 'NULL', 'n/a', '#N/A', 'NA', '-', '|')
      THEN NULL
    WHEN value_raw LIKE '%-%' AND NOT REGEXP_LIKE(value_raw, '^-?[0-9]+\.?[0-9]*$') THEN NULL
    ELSE TRY_TO_NUMBER(
      TRANSLATE(
        UPPER(TRIM(value_raw)), 
        ' ,-$%#REF!#NAME?#ERROR!#DIV/0!', ''  -- Remove noise
      )
    )
  END AS value
FROM flattened
WHERE value IS NOT NULL
  AND year BETWEEN 2003 AND 2033
  AND country IS NOT NULL
  AND country NOT IN ('', 'Total - World')
ORDER BY country, year