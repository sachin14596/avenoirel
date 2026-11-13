WITH source AS (
    SELECT * FROM {{ ref('stg_hotel_properties') }}
),

brand AS (
    SELECT DISTINCT
        {{ dbt_utils.generate_surrogate_key(['brand_code']) }} AS brand_key,
        brand_code,
        brand_name,
        tier
    FROM source
)

SELECT * FROM brand
