WITH tier_movements AS (
    SELECT * FROM {{ ref('int_loyalty_tier_movement') }}
),
final AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['history_id']) }} AS tier_movement_key,
        history_id,
        member_number,
        previous_tier,
        new_tier,
        change_type,
        effective_date,
        status_points_at_change,
        days_at_tier,
        next_tier,
        is_latest_record,
        CURRENT_TIMESTAMP(2) AS loaded_at
    FROM tier_movements
)
SELECT * FROM final