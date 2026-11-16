{{ config(severity='warn', tags=['reconciliation']) }}

-- Known data issue: for most properties the sum of room type inventory in the availability
-- calendar differs from total_rooms in the property master. KPIs use the calendar inventory.
WITH inventory_by_day AS (
    SELECT
        property_code,
        stay_date,
        SUM(total_rooms) AS inventory_rooms
    FROM {{ ref('stg_ops_room_availability') }}
    GROUP BY property_code, stay_date
)

SELECT
    i.property_code,
    p.total_rooms AS master_total_rooms,
    COUNT(*) AS days_mismatched
FROM inventory_by_day AS i
INNER JOIN {{ ref('stg_hotel_properties') }} AS p
    ON i.property_code = p.property_code
WHERE i.inventory_rooms != p.total_rooms
GROUP BY i.property_code, p.total_rooms
