WITH reservations AS (
    SELECT * FROM {{ ref('stg_hotel_reservations') }}
),

properties AS (
    SELECT * FROM {{ ref('stg_hotel_properties') }}
),

joined AS (
    SELECT
        r.confirmation_number,
        r.property_code,
        r.guest_profile_id,
        r.booking_date,
        r.check_in_date,
        r.check_out_date,
        r.nights,
        r.booking_status,
        r.total_cost,
        r.local_currency,
        p.brand_code,
        DATEDIFF(DAY, r.booking_date, r.check_in_date) AS lead_time_days,
        AVG(r.nights) OVER (PARTITION BY p.brand_code) AS avg_los_by_brand,
        AVG(r.nights)
            OVER (PARTITION BY r.property_code)
            AS avg_los_by_property,
        SUM(r.total_cost)
            OVER (PARTITION BY r.guest_profile_id ORDER BY r.booking_date)
            AS running_revenue_by_guest,
        RANK()
            OVER (PARTITION BY r.property_code ORDER BY r.total_cost DESC)
            AS property_booking_rank,
        NTILE(4)
            OVER (ORDER BY DATEDIFF(DAY, r.booking_date, r.check_in_date))
            AS lead_time_quartile
    FROM reservations AS r
    INNER JOIN properties AS p ON r.property_code = p.property_code
),

final AS (
    SELECT * FROM joined
)

SELECT * FROM final
