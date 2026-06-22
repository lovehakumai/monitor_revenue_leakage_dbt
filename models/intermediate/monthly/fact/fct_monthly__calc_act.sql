WITH 
base AS (SELECT * FROM {{ref('fct_monthly__datespine')}})
SELECT 
    subscription_id
    , account_id
    , month_trunc
    , start_date
    , end_date
    , churn_flg
    , mrr_amount
    , refund_amount_usd
    , usage_count
    , is_churned
    , CASE WHEN DATE_TRUNC(MONTH, start_date) = month_trunc THEN 1 ELSE 0 END AS is_started
    {# In Churned month, user has to pay but they don't need to pay from 2nd month#}
    , ( CASE WHEN SUM(churn_flg)OVER(PARTITION BY subscription_id ORDER BY month_trunc) > 1 THEN 0 ELSE mrr_amount END) - refund_amount_usd AS act_month_usd
FROM base