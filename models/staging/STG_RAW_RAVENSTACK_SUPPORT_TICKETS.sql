with source as (
    select * from {{ source('revenstack', 'RAW_RAVENSTACK_SUPPORT_TICKETS') }}
),
renamed as (
    select
        ticket_id,
        account_id,
        submitted_at,
        closed_at,
        resolution_time_hours,
        priority,
        first_response_time_minutes,
        satisfaction_score,
        escalation_flag
    from source
)
select * from renamed