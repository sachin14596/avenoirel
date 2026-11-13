with reservations as(
    select * from {{ ref('stg_hotel_reservations') }}
),
prop as(
    select * from {{ ref('dim_property') }} where is_current=true
),
folio as(
    select * from {{ ref('int_booking_payment_reconciliation') }}
),
joined as(
    select reservations.*, prop.property_key,folio.total_cost_eur from reservations 
    left join prop on reservations.property_code=prop.property_code
    left join folio on reservations.CONFIRMATION_NUMBER=folio.CONFIRMATION_NUMBER
),
bookings as(
select
    {{dbt_utils.generate_surrogate_key(['CONFIRMATION_NUMBER'])}} as booking_key,
    CONFIRMATION_NUMBER,
    property_key,
    property_code,
    guest_profile_id,
    booking_date,
    check_in_date,
    check_out_date,
    rate_channel,
    booking_status,
    datediff(day,check_in_date,check_out_date) as length_of_stay_nights,
    datediff(day,booking_date,check_in_date) as lead_time_days,
    total_cost_eur,
    case when UPPER(rate_channel)='DIRECT' then true else false end as is_direct_booking,
    current_timestamp(2) as loaded_at
    from joined
)
select * from bookings