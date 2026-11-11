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
        MAX(total_rooms)      AS total_rooms,
        SUM(ooo_rooms)        AS ooo_rooms,
        MAX(total_rooms) - SUM(ooo_rooms) AS rooms_available
    FROM availability
    GROUP BY property_code, stay_date
),

revenue_by_property AS (
    SELECT
        r.property_code,
        a.stay_date,
        COUNT(r.booking_status)        AS rooms_sold,
        COALESCE(SUM(f.amount_eur), 0) AS room_revenue_eur
    FROM availability AS a
    LEFT JOIN reservations AS r
        ON  a.property_code = r.property_code
        AND a.stay_date >= r.check_in_date
        AND a.stay_date < r.check_out_date
        AND r.booking_status IN ('CHECKED_IN', 'CHECKED_OUT', 'NO_SHOW')
    LEFT JOIN folios AS f
        ON  r.confirmation_number = f.confirmation_number
        AND f.charge_type = 'ROOM'
    GROUP BY r.property_code, a.stay_date
),

aggregated AS (
    SELECT
        a.property_code,
        a.stay_date,
        a.total_rooms,
        a.ooo_rooms,
        a.rooms_available,
        COALESCE(r.rooms_sold, 0)      AS rooms_sold,
        COALESCE(r.room_revenue_eur, 0) AS room_revenue_eur
    FROM availability_by_property AS a
    LEFT JOIN revenue_by_property AS r
        ON  a.property_code = r.property_code
        AND a.stay_date = r.stay_date
),

final AS (
    SELECT
        property_code,
        stay_date,
        total_rooms,
        ooo_rooms,
        rooms_available,
        rooms_sold,
        room_revenue_eur,
        ROUND(room_revenue_eur / NULLIF(rooms_sold, 0), 2)      AS avg_daily_rate_eur,
        ROUND(rooms_sold / NULLIF(rooms_available, 0) * 1.0, 4) AS occupancy_rate,
        ROUND(room_revenue_eur / NULLIF(rooms_available, 0), 2)  AS revpar_eur
    FROM aggregated
)

SELECT * FROM final