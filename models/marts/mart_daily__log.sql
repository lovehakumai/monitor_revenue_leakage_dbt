WITH 
subscription AS (SELECT * FROM {{ref('STG_RAW_RAVENSTACK_SUBSCRIPTIONS')}})
, churn AS (SELECT * FROM {{ref('STG_RAW_RAVENSTACK_CHURN_EVENTS')}})
, calendar AS (SELECT cl_date FROM {{ref('STG_CMN_CALENDAR')}})
, id_mst AS (
    SELECT 
        subscription_id
        , account_id 
    FROM subscription
    GROUP BY 
        subscription_id
        , account_id 
)
, usage AS (
    SELECT 
        subscription_id
        , usage_date
    FROM {{ref('STG_RAW_RAVENSTACK_FEATURE_USAGE')}}
    GROUP BY 
        subscription_id
        , usage_date
)
, date_spine AS (
    SELECT 
        subscription_id
        , account_id 
        , cl_date
    FROM id_mst 
    CROSS JOIN calendar
    WHERE cl_date >= DATEADD(month, -1, DATE_TRUNC('month', (SELECT MIN(start_date) FROM subscription WHERE subscription_id = id_mst.subscription_id)))
)
, daily_log AS (
    SELECT 
        date_spine.subscription_id
        , date_spine.account_id
        , date_spine.cl_date 
        , subscription.plan_tier AS subscription_tier
        , subscription.start_date
        , NVL(subscription.end_date, '2999-01-01'::DATE) AS end_date
        , CASE WHEN usage.subscription_id IS NOT NULL THEN 1 ELSE 0 END AS is_used
        , MAX(CASE WHEN churn.churn_event_id IS NOT NULL THEN 1 ELSE 0 END)
            OVER(
                PARTITION BY date_spine.subscription_id, date_spine.account_id 
                ORDER BY date_spine.cl_date 
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW 
            ) AS is_churned
        , CASE WHEN date_spine.cl_date = subscription.start_date THEN 1 ELSE 0 END AS is_started
    FROM date_spine
    LEFT JOIN subscription
    ON date_spine.subscription_id = subscription.subscription_id
    LEFT JOIN usage 
    ON date_spine.cl_date = usage.usage_date
        AND date_spine.subscription_id = usage.subscription_id
    LEFT JOIN churn
    ON date_spine.account_id = churn.account_id 
        AND date_spine.cl_date = churn.churn_date
    WHERE cl_date >= '2023-01-01'::DATE
)
, get_status AS (
    SELECT 
        subscription_id
        , account_id
        , cl_date 
        , subscription_tier
        , start_date
        , end_date
        , is_used
        , is_churned
        , is_started
        , CASE 
            WHEN (cl_date BETWEEN start_date AND end_date) AND (is_churned = 0) AND (is_used IN (0, 1)) THEN 'Correct'
            WHEN (cl_date BETWEEN start_date AND end_date) AND (is_churned = 1) AND (is_used = 0) THEN 'Correct Not Used After Churn'
            WHEN (cl_date BETWEEN start_date AND end_date) AND (is_churned = 1) AND (is_used = 1) THEN 'Incorrect Used After Churn'
            WHEN (cl_date >= end_date) AND (is_used = 0) THEN 'Correct Not Used After Expiration'
            WHEN (cl_date >= end_date) AND (is_used = 1) THEN 'Incorrect Used After Expiration'
            WHEN (cl_date <= start_date) AND (is_used = 0) THEN 'Correct Not Used Before Start'
            WHEN (cl_date <= start_date) AND (is_used = 1) THEN 'Incorrect Used Before Start'
            ELSE 'Others'
            END AS usage_status
    FROM daily_log
)
SELECT * 
FROM get_status 
ORDER BY 
    subscription_id
    , account_id
    , cl_date 