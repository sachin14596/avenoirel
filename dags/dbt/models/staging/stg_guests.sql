WITH source AS (
    SELECT * FROM {{ source('avenoirel_raw', 'guests') }}
),

renamed AS (
    SELECT
        guest_profile_id::VARCHAR AS guest_profile_id,
        title::VARCHAR AS guest_title,
        first_name::VARCHAR AS guest_first_name,
        last_name::VARCHAR AS guest_last_name,
        email::VARCHAR AS guest_email,
        phone::VARCHAR AS guest_phone,
        address::VARCHAR AS guest_address,
        nationality_code::VARCHAR AS nationality_code,
        is_avenir_member::BOOLEAN AS is_avenir_member,
        has_invalid_name::BOOLEAN AS has_invalid_name,
        has_garbled_name::BOOLEAN AS has_garbled_name,
        has_invalid_email::BOOLEAN AS has_invalid_email,
        has_missing_phone::BOOLEAN AS has_missing_phone,
        has_missing_address::BOOLEAN AS has_missing_address,
        created_at::DATE AS created_at
    FROM source
    WHERE guest_profile_id IS NOT NULL
)

SELECT * FROM renamed
