WITH source AS (
    SELECT * FROM {{ source('avenoirel_raw', 'avenir_points_transactions') }}
),

renamed AS (
    SELECT
        transaction_id::VARCHAR AS transaction_id,
        member_number::VARCHAR AS member_number,
        confirmation_number::VARCHAR AS confirmation_number,
        transaction_type::VARCHAR AS transaction_type,
        transaction_date::DATE AS transaction_date,
        status_points::INTEGER AS status_points,
        reward_points::INTEGER AS reward_points,
        tier_at_earn::VARCHAR AS tier_at_earn,
        property_code::VARCHAR AS property_code,
        has_early_points::BOOLEAN AS has_early_points
    FROM source
    WHERE transaction_id IS NOT NULL
)

SELECT * FROM renamed
