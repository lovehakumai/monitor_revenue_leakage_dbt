{#================================================================================
 account_id, year_month, expected_montly_revenue, actual_monthly_revenue
================================================================================ #}
WITH 
subscription AS (SELECT * FROM {{ref('STG_RAW_RAVENSTACK_SUBSCRIPTIONS')}})
, account AS (SELECT * FROM {{ref('STG_RAW_RAVENSTACK_ACCOUNTS')}})
, churn AS (SELECT * FROM {{ref('STG_RAW_RAVENSTACK_CHURN_EVENTS')}})
, calendar AS (SELECT * FROM {{ref('STG_CMN_CALENDAR')}})
, usage AS (SELECT * FROM {{ref('STG_RAW_RAVENSTACK_FEATURE_USAGE')}})
, usage_month AS (SELECT * FROM {{ref('fct_monthly__usage_month')}})

, subscription_mst AS (
    {# grain : subscription_id #}
    SELECT 
        subscription_id
        , start_date
    FROM subscription
    GROUP BY 
        subscription_id
        , start_date
)
, date_range AS (
    SELECT 
        MIN(min_date) AS min_date
        , MAX(max_date) AS max_date
    FROM (
        SELECT 
            MIN(usage_date) AS min_date
            , MAX(usage_date) AS max_date
        FROM usage 
        UNION ALL 
        SELECT 
            MIN(start_date) AS min_date
            , MAX(end_date) AS max_date
        FROM subscription
    )
)
, calendar_month AS (
    SELECT DISTINCT 
        DATE_TRUNC('month', cl_date) AS month_trunc
    FROM calendar
    WHERE
        cl_date BETWEEN (SELECT min_date FROM date_range) AND (SELECT max_date FROM date_range) 
)
, subscription_month_cross AS (
    SELECT 
        subscription_id
        , month_trunc
    FROM subscription_mst
    CROSS JOIN calendar_month    
    WHERE 
        month_trunc >= DATE_TRUNC('month', start_date)
)
, churn_month AS (
    SELECT 
        account_id
        , DATE_TRUNC('month', churn_date) AS churn_month
        , SUM(refund_amount_usd) AS refund_amount_usd
    FROM churn
    GROUP BY 
        account_id
        , DATE_TRUNC('month', churn_date)
)
, subscription_datespine AS (
    SELECT 
        base.subscription_id
        , subsc_dim.account_id
        , month_trunc
        , subsc_dim.start_date
        , COALESCE(subsc_dim.end_date, '2999-01-01') AS end_date {#end_date is nullable for active plans#}
        , CASE WHEN churn_month.account_id IS NOT NULl THEN 1 ELSE 0 END AS is_churned
        , MAX(CASE WHEN churn_month.account_id IS NOT NULL THEN 1 ELSE 0 END)
            OVER (
                PARTITION BY base.subscription_id, subsc_dim.account_id 
                ORDER BY month_trunc
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) AS churn_flg {# Cumulative Max for carry flg foward following churn event #}
        , NVL(subsc_amt.mrr_amount, 0 ) AS mrr_amount
        , NVL(churn_month.refund_amount_usd, 0) AS refund_amount_usd
        , NVL(usage_count, 0) AS usage_count
    FROM subscription_month_cross AS base
    
    LEFT JOIN subscription AS subsc_amt
    ON base.subscription_id = subsc_amt.subscription_id
        AND month_trunc BETWEEN DATE_TRUNC('month', subsc_amt.start_date) AND DATEADD(day, -1, DATEADD(month, 1, DATE_TRUNC('month', NVL(subsc_amt.end_date, '2999-01-01'))))
    
    LEFT JOIN subscription AS subsc_dim
    ON base.subscription_id = subsc_dim.subscription_id
    
    LEFT JOIN churn_month
    ON subsc_dim.account_id = churn_month.account_id
        AND base.month_trunc = churn_month.churn_month
    
    LEFT JOIN usage_month 
    ON base.subscription_id = usage_month.subscription_id
        AND base.month_trunc = usage_month.usage_month
)
SELECT * FROM subscription_datespine 