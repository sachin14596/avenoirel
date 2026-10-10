WITH transactions AS (
    SELECT * FROM {{ ref('stg_avenir_points_transactions') }}
),

reservations AS (
    SELECT * FROM {{ ref('stg_hotel_reservations') }}
),

joined AS (
    SELECT
        tr.transaction_id,
        tr.member_number,
        tr.confirmation_number,
        tr.transaction_type,
        tr.transaction_date,
        tr.status_points,
        tr.reward_points,
        tr.tier_at_earn,
        tr.property_code,
        r.check_out_date,
        tr.has_early_points,
        CASE
            WHEN r.check_out_date IS NULL THEN TRUE
            WHEN tr.transaction_date >= r.check_out_date THEN TRUE
            ELSE FALSE
        END AS is_valid_transaction
    FROM transactions AS tr
    LEFT JOIN reservations AS r
        ON tr.confirmation_number = r.confirmation_number
),

final AS (
    SELECT * FROM joined
)

SELECT * FROM final
