WITH 
date_spine AS (SELECT * FROM {{ref('fct_ravenstack__datespine')}})
, usage AS (SELECT * FROM {{ref('fct_ravenstack__usage_month')}})
, base AS (
    SELECT 
        date_spine.subscription_id
        , account_id
        , month_trunc
        , start_date
        , end_date {#end_date is nullable for active plans#}
        , churn_flg {# Cumulative Max for carry flg foward following churn event #}
        , mrr_amount
        , refund_amount_usd
        , usage_count
    FROM date_spine
    LEFT JOIN usage
    ON date_spine.subscription_id = usage.subscription_id
        AND date_spine.month_trunc = usage.usage_month
)
SELECT * FROM base