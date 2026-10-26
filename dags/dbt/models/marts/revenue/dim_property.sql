WITH source AS (
    SELECT * FROM {{ ref('snap_hotel_properties') }}
),

properties AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['property_code','dbt_valid_from']) }} AS property_key,
        property_code,
        property_name,
        brand_code,
        brand_name,
        tier,
        star_rating,
        city,
        country_code,
        local_currency,
        total_rooms,
        has_restaurant,
        has_parking,
        has_spa,
        dbt_valid_from,
        dbt_valid_to,
        coalesce(dbt_valid_to IS null, false) AS is_current
    FROM source
)

SELECT * FROM properties
