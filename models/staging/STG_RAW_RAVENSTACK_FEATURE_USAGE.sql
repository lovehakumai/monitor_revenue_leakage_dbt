with source as (
    select * from {{ source('revenstack', 'RAW_RAVENSTACK_FEATURE_USAGE') }}
),
renamed as (
    select
        usage_id,
        subscription_id,
        usage_date,
        feature_name,
        usage_count,
        usage_duration_secs,
        error_count,
        is_beta_feature
    from source
)
select * from renamed