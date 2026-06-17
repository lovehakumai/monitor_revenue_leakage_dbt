WITH 
base AS (SELECT * FROM {{ref('STG_RAW_RAVENSTACK_FEATURE_USAGE')}})
, month_agg AS (
    SELECT 
        subscription_id
        , DATE_TRUNC('month', usage_date) AS usage_month
        , SUM(usage_count) AS usage_count
    FROM base
    GROUP BY 
        subscription_id
        , DATE_TRUNC('month', usage_date)
)
SELECT * FROM month_agg