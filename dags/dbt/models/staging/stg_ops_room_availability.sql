WITH source AS (
    SELECT * FROM {{ source('avenoirel_raw', 'room_availability') }}
),

renamed AS (
    SELECT
        availability_id::VARCHAR AS availability_id,
        property_code::VARCHAR AS property_code,
        room_type_id::VARCHAR AS room_type_id,
        stay_date::DATE AS stay_date,
        total_rooms::INTEGER AS total_rooms,
        ooo_rooms::INTEGER AS ooo_rooms,
        rooms_available::INTEGER AS rooms_available
    FROM source
    WHERE availability_id IS NOT NULL
)

SELECT * FROM renamed
