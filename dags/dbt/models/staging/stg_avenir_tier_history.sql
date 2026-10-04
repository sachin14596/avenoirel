WITH source AS (
    SELECT * FROM {{ source('avenoirel_raw', 'avenir_tier_history') }}
),

renamed AS (
    SELECT
        history_id::VARCHAR AS history_id,
        member_number::VARCHAR AS member_number,
        previous_tier::VARCHAR AS previous_tier,
        new_tier::VARCHAR AS new_tier,
        change_type::VARCHAR AS change_type,
        effective_date::DATE AS effective_date,
        status_points_at_change::INTEGER AS status_points_at_change
    FROM source
    WHERE history_id IS NOT NULL
)

SELECT * FROM renamed
