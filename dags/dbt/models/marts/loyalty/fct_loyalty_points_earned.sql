WITH points_validated AS (
    SELECT * FROM {{ ref('int_loyalty_points_validated') }}
),
prop AS (
    SELECT * FROM {{ ref('dim_property') }} WHERE is_current = TRUE
),
joined AS (
    SELECT
        p.*,
        pr.property_key
    FROM points_validated AS p
    LEFT JOIN prop AS pr ON p.property_code = pr.property_code
),
final AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['transaction_id']) }} AS points_earned_key,
        transaction_id,
        property_key,
        property_code,
        member_number,
        confirmation_number,
        transaction_type,
        transaction_date,
        status_points,
        reward_points,
        tier_at_earn,
        CURRENT_TIMESTAMP(2) AS loaded_at
    FROM joined
    WHERE is_valid_transaction = TRUE
)
SELECT * FROM final