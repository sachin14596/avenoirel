WITH source AS (
    SELECT * FROM {{ source('avenoirel_raw', 'properties') }}
),

renamed AS (
    SELECT
        property_code::VARCHAR AS property_code,
        property_name::VARCHAR AS property_name,
        brand_code::VARCHAR AS brand_code,
        brand_name::VARCHAR AS brand_name,
        tier::VARCHAR AS tier,
        star_rating::INTEGER AS star_rating,
        city::VARCHAR AS city,
        country_code::VARCHAR AS country_code,
        local_currency::VARCHAR AS local_currency,
        total_rooms::INTEGER AS total_rooms,
        has_restaurant::BOOLEAN AS has_restaurant,
        has_parking::BOOLEAN AS has_parking,
        has_spa::BOOLEAN AS has_spa,
        created_at::DATE AS created_at
    FROM source
    WHERE property_code IS NOT NULL
)

SELECT * FROM renamed
