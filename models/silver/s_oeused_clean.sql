-- models/silver/s_oeused_clean.sql
{{ config(materialized='table', schema='SLV') }}

/*
  FAIL-SAFE: Use positional references ($1, $2) to avoid "invalid identifier" errors
  Source: RAW.OEUSED (from Excel sheet 'OEused')
*/

WITH raw AS (
  SELECT 
    $1 AS country,
    $2 AS indicator_used,
    $3 AS corr_raw,
    $4 AS slope_raw,
    $5 AS intercept_raw,
    $6 AS cagr_raw,
    $7 AS swip_flag
  FROM {{ source('raw', 'OEUSED') }}
  WHERE $1 IS NOT NULL
    AND $1 NOT IN ('', 'Total - World', 'WSA and file calculation match', '|||||||||||||||||||||||||||||||||||||||||||')
),

cleaned AS (
  SELECT
    country,
    indicator_used,
    -- Clean correlation (e.g., 78% ? 0.78)
    CASE
      WHEN corr_raw IN ('#REF!', '#NAME?', '#ERROR!', '', 'NULL', 'n/a', '#N/A') THEN NULL
      WHEN corr_raw LIKE '%-%' THEN NULL  -- Invalid
      ELSE 
        CASE 
          WHEN corr_raw LIKE '%%' 
          THEN TO_NUMBER(REPLACE(corr_raw, '%', '')) / 100.0
          ELSE TO_NUMBER(corr_raw)
        END
    END AS corr,
    -- Clean slope
    CASE
      WHEN slope_raw IN ('#REF!', '#NAME?', '#ERROR!', '', 'NULL', 'n/a', '#N/A') THEN NULL
      ELSE TO_NUMBER(REPLACE(slope_raw, ',', ''))
    END AS slope,
    -- Clean intercept
    CASE
      WHEN intercept_raw IN ('#REF!', '#NAME?', '#ERROR!', '', 'NULL', 'n/a', '#N/A') THEN NULL
      ELSE TO_NUMBER(REPLACE(intercept_raw, ',', ''))
    END AS intercept,
    -- Clean CAGR
    CASE
      WHEN cagr_raw IN ('#REF!', '#NAME?', '#ERROR!', '', 'NULL', 'n/a', '#N/A') THEN NULL
      WHEN cagr_raw LIKE '%%' 
      THEN TO_NUMBER(REPLACE(cagr_raw, '%', '')) / 100.0
      ELSE TO_NUMBER(cagr_raw)
    END AS cagr
  FROM raw
)

SELECT 
  *,
  -- Flag whether to use SWIP fallback
  CASE
    WHEN corr IS NULL OR corr < 0.7 THEN 'SWIP'
    ELSE 'OE_INDICATOR'
  END AS primary_indicator
FROM cleaned
WHERE country IS NOT NULL
ORDER BY country