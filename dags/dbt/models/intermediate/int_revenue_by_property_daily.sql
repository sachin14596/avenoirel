WITH availability AS (
    SELECT * FROM {{ ref('stg_ops_room_availability') }}
),

reservations AS (
    SELECT * FROM {{ ref('stg_hotel_reservations') }}
),

folios AS (
    SELECT * FROM {{ ref('stg_hotel_folios') }}
),

availability_by_property AS (
    SELECT
        property_code,
        stay_date,
        SUM(total_rooms) AS total_rooms,
        SUM(ooo_rooms) AS ooo_rooms,
        SUM(total_rooms) - SUM(ooo_rooms) AS rooms_available
    FROM availability
    GROUP BY property_code, stay_date
),

sold_stays AS (
    SELECT
        r.confirmation_number,
        r.property_code,
        r.check_in_date,
        r.check_out_date,
        DATEDIFF('day', r.check_in_date, r.check_out_date) AS nights_stayed,
        SUM(f.amount_eur) AS stay_room_revenue_eur
    FROM reservations AS r
    LEFT JOIN folios AS f
        ON
            r.confirmation_number = f.confirmation_number
            AND f.charge_type = 'ROOM'
    WHERE
        r.booking_status IN ('CHECKED_IN', 'CHECKED_OUT', 'NO_SHOW')
        AND COALESCE(r.is_test_record, FALSE) = FALSE
        AND COALESCE(r.is_duplicate_reservation, FALSE) = FALSE
    GROUP BY
        r.confirmation_number,
        r.property_code,
        r.check_in_date,
        r.check_out_date
),

nightly_sales AS (
    SELECT
        a.property_code,
        a.stay_date,
        COUNT(s.confirmation_number) AS rooms_sold,
        COALESCE(SUM(s.stay_room_revenue_eur / NULLIF(s.nights_stayed, 0)), 0) AS room_revenue_eur
    FROM availability_by_property AS a
    LEFT JOIN sold_stays AS s
        ON
            a.property_code = s.property_code
            AND a.stay_date >= s.check_in_date
            AND a.stay_date < s.check_out_date
    GROUP BY a.property_code, a.stay_date
),

final AS (
    SELECT
        a.property_code,
        a.stay_date,
        a.total_rooms,
        a.ooo_rooms,
        a.rooms_available,
        n.rooms_sold,
        n.room_revenue_eur,
        ROUND(n.room_revenue_eur / NULLIF(n.rooms_sold, 0), 2) AS avg_daily_rate_eur,
        ROUND(n.rooms_sold / NULLIF(a.rooms_available, 0) * 1.0, 4) AS occupancy_rate,
        ROUND(n.room_revenue_eur / NULLIF(a.rooms_available, 0), 2) AS revpar_eur
    FROM availability_by_property AS a
    INNER JOIN nightly_sales AS n
        ON
            a.property_code = n.property_code
            AND a.stay_date = n.stay_date
)

SELECT * FROM final
