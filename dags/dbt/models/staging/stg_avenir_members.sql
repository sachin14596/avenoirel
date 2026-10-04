WITH source AS (
    SELECT * FROM {{ source('avenoirel_raw', 'avenir_members') }}
),

renamed AS (
    SELECT
        member_number::VARCHAR AS member_number,
        guest_profile_id::VARCHAR AS guest_profile_id,
        current_tier::VARCHAR AS current_tier,
        join_date::DATE AS join_date,
        lifetime_nights::INTEGER AS lifetime_nights,
        lifetime_status_points::INTEGER AS lifetime_status_points,
        current_reward_points::INTEGER AS current_reward_points,
        created_at::DATE AS created_at
    FROM source
    WHERE member_number IS NOT NULL
)

SELECT * FROM renamed
