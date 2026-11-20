WITH source AS (
    SELECT * FROM {{ ref('stg_guests') }}
),

guests AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['guest_profile_id']) }} AS guest_key,
        guest_profile_id,
        guest_title,
        guest_first_name,
        guest_last_name,
        guest_email,
        guest_phone,
        guest_address,
        nationality_code,
        is_avenir_member,
        has_invalid_name,
        has_garbled_name,
        has_invalid_email,
        has_missing_phone,
        has_missing_address,
        created_at AS created_date
    FROM source
),

final AS (
    SELECT * FROM guests
)

SELECT * FROM final
