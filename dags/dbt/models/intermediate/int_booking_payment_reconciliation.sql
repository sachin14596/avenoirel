WITH reservations AS (
    SELECT * FROM {{ ref('stg_hotel_reservations') }}
),

folios AS (
    SELECT * FROM {{ ref('stg_hotel_folios') }}
),

joined AS (
    SELECT
        r.confirmation_number,
        r.property_code,
        r.booking_status,
        r.total_cost,
        r.local_currency,
        CASE
            WHEN r.local_currency = 'GBP' THEN r.total_cost * 1.17
            WHEN r.local_currency = 'AED' THEN r.total_cost * 0.25
            ELSE r.total_cost
        END AS total_cost_eur,
        SUM(f.amount_eur) AS total_paid_eur
    FROM reservations AS r
    LEFT JOIN folios AS f ON r.confirmation_number = f.confirmation_number
    GROUP BY
        r.confirmation_number,
        r.property_code,
        r.booking_status,
        r.total_cost,
        r.local_currency
),

aggregation AS (
    SELECT
        confirmation_number,
        property_code,
        booking_status,
        total_cost,
        local_currency,
        total_cost_eur,
        total_paid_eur,
        total_paid_eur - total_cost_eur AS payment_gap_eur,
        NOT COALESCE(ABS(total_paid_eur - total_cost_eur) <= 1, FALSE) AS has_payment_mismatch
    FROM joined
),

final AS (
    SELECT
        confirmation_number,
        property_code,
        booking_status,
        total_cost,
        local_currency,
        total_cost_eur,
        total_paid_eur,
        payment_gap_eur,
        has_payment_mismatch,
        PERCENT_RANK()
            OVER (ORDER BY payment_gap_eur ASC)
            AS payment_gap_percentile,
        CUME_DIST()
            OVER (ORDER BY payment_gap_eur ASC)
            AS payment_gap_cumulative
    FROM aggregation
)

SELECT * FROM final
