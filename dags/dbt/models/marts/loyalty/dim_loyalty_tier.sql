WITH source AS (
    SELECT * FROM {{ ref('avenir_tiers') }}
),

final AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['tier_key']) }} AS loyalty_tier_key,
        tier_key,
        tier_name,
        min_nights,
        max_nights,
        status_points_multiplier,
        reward_points_multiplier,
        tier_description,
        CURRENT_TIMESTAMP AS created_at
    FROM source
)

SELECT * FROM final
