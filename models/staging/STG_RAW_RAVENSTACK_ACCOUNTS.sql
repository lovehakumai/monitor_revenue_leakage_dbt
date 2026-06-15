with source as (
    select * from {{ source('revenstack', 'RAW_RAVENSTACK_ACCOUNTS') }}
),
renamed as (
    select
        account_id,
        account_name,
        industry,
        country,
        TO_DATE(signup_date) AS signup_date,
        referral_source,
        plan_tier,
        seats,
        is_trial,
        churn_flag
    from source
)
select * from renamed