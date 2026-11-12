WITH revenue_by_property_daily AS (
    SELECT * FROM {{ ref('int_revenue_by_property_daily') }}
),
dim_prop AS (
    SELECT * FROM {{ ref('dim_property') }} WHERE is_current = TRUE
),
joined AS (
    SELECT
        rp.*,
        p.property_key
    FROM revenue_by_property_daily AS rp
    LEFT JOIN dim_prop AS p ON rp.property_code = p.property_code
),
final AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['property_code', 'stay_date']) }} AS occupancy_key,
        property_key,
        property_code,
        stay_date,
        total_rooms,
        ooo_rooms,
        rooms_available,
        rooms_sold,
        occupancy_rate,
        CURRENT_TIMESTAMP(2) AS loaded_at
    FROM joined
)
SELECT * FROM final