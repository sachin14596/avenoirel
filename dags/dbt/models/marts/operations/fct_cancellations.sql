WITH cancellations AS (
    SELECT * FROM {{ ref('int_booking_cancellation_signals') }}
),
prop AS (
    SELECT * FROM {{ ref('dim_property') }} WHERE is_current = TRUE
),
joined AS (
    SELECT
        c.*,
        p.property_key
    FROM cancellations AS c
    LEFT JOIN prop AS p ON c.property_code = p.property_code
),
final AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['confirmation_number']) }} AS cancellation_key,
        confirmation_number,
        property_key,
        property_code,
        booking_date,
        check_in_date,
        cancellation_date,
        rate_channel,
        market_segment,
        reason_code,
        reason_group,
        days_before_checkin,
        cancellation_window,
        is_last_minute,
        is_direct_booking,
        revenue_at_risk                                                AS revenue_at_risk_local,
        local_currency,
        CURRENT_TIMESTAMP(2)                                           AS loaded_at
    FROM joined
)
SELECT * FROM final