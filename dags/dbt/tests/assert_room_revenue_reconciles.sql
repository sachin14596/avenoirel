{{ config(tags=['reconciliation']) }}

-- Night audit: room revenue in the model must equal the clean ROOM folio revenue in staging,
-- spread evenly across nights and limited to the availability calendar. Tolerance: EUR 1.
WITH calendar AS (
    SELECT
        MIN(stay_date) AS first_day,
        MAX(stay_date) AS last_day
    FROM {{ ref('stg_ops_room_availability') }}
),

staging_revenue AS (
    SELECT
        SUM(
            f.amount_eur
            / NULLIF(DATEDIFF('day', r.check_in_date, r.check_out_date), 0)
            * GREATEST(
                0,
                DATEDIFF(
                    'day',
                    GREATEST(r.check_in_date, c.first_day),
                    LEAST(r.check_out_date, DATEADD('day', 1, c.last_day))
                )
            )
        ) AS revenue_eur
    FROM {{ ref('stg_hotel_reservations') }} AS r
    INNER JOIN {{ ref('stg_hotel_folios') }} AS f
        ON
            r.confirmation_number = f.confirmation_number
            AND f.charge_type = 'ROOM'
    CROSS JOIN calendar AS c
    WHERE
        r.booking_status IN ('CHECKED_IN', 'CHECKED_OUT', 'NO_SHOW')
        AND COALESCE(r.is_test_record, FALSE) = FALSE
        AND COALESCE(r.is_duplicate_reservation, FALSE) = FALSE
),

model_revenue AS (
    SELECT SUM(room_revenue_eur) AS revenue_eur
    FROM {{ ref('int_revenue_by_property_daily') }}
)

SELECT
    s.revenue_eur AS staging_revenue_eur,
    m.revenue_eur AS model_revenue_eur
FROM staging_revenue AS s
CROSS JOIN model_revenue AS m
WHERE ABS(s.revenue_eur - m.revenue_eur) > 1
