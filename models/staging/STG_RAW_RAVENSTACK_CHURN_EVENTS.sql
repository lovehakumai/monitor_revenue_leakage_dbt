with source as (
    select * from {{ source('revenstack', 'RAW_RAVENSTACK_CHURN_EVENTS') }}
),
renamed as (
    select
        churn_event_id,
        account_id,
        TO_DATE(churn_date) AS churn_date,
        reason_code,
        refund_amount_usd,
        preceding_upgrade_flag,
        preceding_downgrade_flag,
        is_reactivation,
        feedback_text
    from source
)
select * from renamed