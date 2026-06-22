WITH 
base AS (SELECT * FROM {{ref('fct_monthly__calc_act')}})

, account_agg_raw AS (
    SELECT 
        account_id
        , month_trunc
        , SUM(is_churned) AS is_churned_sum
        , SUM(is_started) AS is_started_sum
        , SUM(mrr_amount) AS mrr_amount
        , SUM(refund_amount_usd) AS refund_amount_usd
        , SUM(act_month_usd) AS act_month_usd
        , SUM(usage_count) AS usage_count
    FROM base 
    GROUP BY 
        account_id
        , month_trunc
)
, account_agg AS (
    SELECT 
        account_id
        , month_trunc
        , CASE WHEN is_churned_sum > 0 THEN 1 ELSE 0 END AS is_churned 
        , CASE WHEN is_started_sum > 0 THEN 1 ELSE 0 END AS is_started
        , mrr_amount
        , refund_amount_usd
        , act_month_usd
        , usage_count
    FROM account_agg_raw
)
, account_mst AS (
    SELECT
        account_id
    FROM account_agg
    GROUP BY 
        account_id
)
, date_range AS (
    SELECT
        MIN(month_trunc) AS min_date
        , MAX(month_trunc) AS max_date
    FROM account_agg
)
, calendar AS (
    SELECT 
        DATE_TRUNC('month', cl_date) AS cal_month
    FROM {{ref('STG_CMN_CALENDAR')}} 
    WHERE cl_date BETWEEN (SELECT min_date FROM date_range) AND (SELECT max_date FROM date_range)
    GROUP BY 
        DATE_TRUNC('month', cl_date) 
)
, date_spine AS (
    SELECT
        account_id
        , cal_month
    FROM account_mst
    CROSS JOIN calendar
)
, account_datespine AS (
    SELECT 
        date_spine.account_id
        , date_spine.cal_month
        , COALESCE(mrr_amount, 0) AS mrr_amount
        , COALESCE(act_month_usd, 0) AS act_month_usd
        , COALESCE(usage_count, 0) AS usage_count
        , NVL(is_started, 0) AS is_started
        , NVL(is_churned, 0) AS is_churned
    FROM date_spine
    LEFT JOIN account_agg
    ON date_spine.account_id = account_agg.account_id
        AND date_spine.cal_month = account_agg.month_trunc
    QUALIFY 
        SUM(COALESCE(mrr_amount, 0))OVER(PARTITION BY date_spine.account_id) > 0
        AND SUM(COALESCE(act_month_usd,0))OVER(PARTITION BY date_spine.account_id) > 0
)
, account_add_status AS (
    SELECT 
        account_id
        , cal_month
        , mrr_amount
        , act_month_usd
        , usage_count
        , is_started
        , is_churned
        {# Account Status is about User's payment, start or churn action is defined in another column #}
        , CASE 
            WHEN
                MAX(act_month_usd)OVER(PARTITION BY account_id ORDER BY cal_month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) = 0
                OR ( cal_month = MIN(cal_month)OVER(PARTITION BY account_id) AND act_month_usd = 0)
                THEN 'Before Activate'
            WHEN 
                MIN(CASE WHEN act_month_usd <> 0 THEN cal_month END ) OVER (PARTITION BY account_id ) = cal_month
                THEN 'First Payment'

            WHEN cal_month <> MIN(cal_month)OVER(PARTITION BY account_id  ) 
                AND LAG(act_month_usd)OVER(PARTITION BY account_id ORDER BY cal_month) = act_month_usd
                AND act_month_usd <> 0
                THEN 'Retain'
            
            WHEN cal_month <> MIN(cal_month)OVER(PARTITION BY account_id )
                AND act_month_usd = 0
                AND LAG(act_month_usd)OVER(PARTITION BY account_id ORDER BY cal_month) > 0
                THEN 'Stop Paying'
            
            WHEN cal_month <> MIN(cal_month)OVER(PARTITION BY account_id )    
                AND LAG(act_month_usd)OVER(PARTITION BY account_id ORDER BY cal_month) = 0
                AND act_month_usd <> 0
                THEN 'Reactivate'

            WHEN cal_month <> MIN(cal_month)OVER(PARTITION BY account_id )    
                AND act_month_usd > LAG(act_month_usd)OVER(PARTITION BY account_id ORDER BY cal_month)
                THEN 'Expansion'

            WHEN cal_month <> MIN(cal_month)OVER(PARTITION BY account_id ) 
                AND act_month_usd < LAG(act_month_usd)OVER(PARTITION BY account_id ORDER BY cal_month)
                THEN 'Contraction'
            
            WHEN LAG(act_month_usd)OVER(PARTITION BY account_id ORDER BY cal_month) = 0
                AND act_month_usd = 0
                THEN 'Suspended'
                        
            ELSE 'Others'

        END AS payment_status
    FROM account_datespine
)
SELECT * FROM account_add_status