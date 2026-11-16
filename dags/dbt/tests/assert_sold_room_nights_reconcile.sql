{{ config(tags=['reconciliation']) }}

-- Night audit: sold room-nights in the model must equal the clean sold room-nights in staging
-- that fall inside the availability calendar. Cancelled bookings, test records and duplicates are out of scope.
WITH calendar AS (
    SELECT
        MIN(stay_date) AS first_day,
        MAX(stay_date) AS last_day
    FROM {{ ref('stg_ops_room_availability') }}
),

staging_nights AS (
    SELECT
        SUM(
            GREATEST(
                0,
                DATEDIFF(
                    'day',
                    GREATEST(r.check_in_date, c.first_day),
                    LEAST(r.check_out_date, DATEADD('day', 1, c.last_day))
                )
            )
        ) AS room_nights
    FROM {{ ref('stg_hotel_reservations') }} AS r
    CROSS JOIN calendar AS c
    WHERE
        r.booking_status IN ('CHECKED_IN', 'CHECKED_OUT', 'NO_SHOW')
        AND COALESCE(r.is_test_record, FALSE) = FALSE
        AND COALESCE(r.is_duplicate_reservation, FALSE) = FALSE
),

model_nights AS (
    SELECT SUM(rooms_sold) AS room_nights
    FROM {{ ref('int_revenue_by_property_daily') }}
)

SELECT
    s.room_nights AS staging_room_nights,
    m.room_nights AS model_room_nights
FROM staging_nights AS s
CROSS JOIN model_nights AS m
WHERE s.room_nights != m.room_nights
