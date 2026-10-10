WITH cancellations AS (
    SELECT * FROM {{ ref('stg_hotel_cancellations') }}
),

reservations AS (
    SELECT * FROM {{ ref('stg_hotel_reservations') }}
),

joined AS (
    SELECT
        c.cancellation_id,
        c.confirmation_number,
        r.property_code,
        r.booking_date,
        r.check_in_date,
        c.cancellation_date,
        c.days_before_checkin,
        c.cancellation_window,
        c.reason_code,
        c.reason_group,
        r.rate_channel,
        r.market_segment,
        r.is_direct_booking,
        c.revenue_at_risk,
        r.local_currency,
        CASE WHEN c.days_before_checkin <= 3 THEN 'Yes' ELSE 'No' END
            AS is_last_minute
    FROM cancellations AS c
    INNER JOIN
        reservations AS r
        ON c.confirmation_number = r.confirmation_number

),

final AS (
    SELECT * FROM joined
)

SELECT * FROM final
