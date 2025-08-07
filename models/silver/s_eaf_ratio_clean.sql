-- models/silver/s_eaf_ratio_clean.sql
{{ config(materialized='table', schema='SLV') }}

WITH raw_eaf AS (
  SELECT 
    $1 AS country,
    $2 AS indicator,
    ARRAY_CONSTRUCT(
      $7,  $8,  $9,  $10, $11, $12, $13, $14, $15, $16,
      $17, $18, $19, $20, $21, $22, $23, $24, $25, $26,
      $27, $28, $29, $30, $31, $32, $33, $34, $35, $36,
      $37, $38, $39, $40, $41, $42, $43, $44, $45
    ) AS year_values
  FROM {{ source('raw', 'OEALLDATA') }}
  WHERE $1 IS NOT NULL
    AND $1 NOT IN ('', 'Total - World', 'WSA and file calculation match', '|||||||||||||||||||||||||||||||||||||||||||')
    AND (
      $2 ILIKE '%EAF%' 
      OR $2 ILIKE '%eaf%'
      OR $2 ILIKE '%arc furnace%'
    )
),

flattened AS (
  SELECT 
    country,
    indicator,
    1994 + SEQ4() AS year,
    VALUE AS value_raw
  FROM raw_eaf,
  LATERAL FLATTEN(input => year_values)
)

SELECT 
  country,
  year,
  CASE
    WHEN value_raw IN ('#REF!', '#NAME?', '#ERROR!', '', 'NULL', 'n/a', '#N/A')
      THEN NULL
    ELSE TRY_TO_NUMBER(CAST(value_raw AS VARCHAR))
  END AS eaf_ratio_pct,
  CASE
    WHEN value_raw IN ('#REF!', '#NAME?', '#ERROR!', '', 'NULL', 'n/a', '#N/A')
      THEN NULL
    ELSE TRY_TO_NUMBER(CAST(value_raw AS VARCHAR)) / 100.0
  END AS eaf_ratio
FROM flattened
WHERE eaf_ratio_pct IS NOT NULL
  AND year BETWEEN 2003 AND 2033
ORDER BY country, year