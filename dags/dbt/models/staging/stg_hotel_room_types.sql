WITH source AS (
    SELECT * FROM {{ source('avenoirel_raw', 'room_types') }}
),

renamed AS (
    SELECT
        room_type_id::VARCHAR AS room_type_id,
        property_code::VARCHAR AS property_code,
        room_type_code::VARCHAR AS room_type_code,
        room_type_name::VARCHAR AS room_type_name,
        is_accessible::BOOLEAN AS is_accessible,
        total_rooms::INTEGER AS total_rooms,
        max_occupancy::INTEGER AS max_occupancy,
        created_at::DATE AS created_at
    FROM source
    WHERE room_type_id IS NOT NULL
)

SELECT * FROM renamed
