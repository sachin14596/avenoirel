with revenue_by_property_daily as(
    select * from {{ ref('int_revenue_by_property_daily') }}
),

dim_prop as(
    select * from {{ ref('dim_property') }} where is_current=true
),

joined as(
    select rp.*,p.property_key from revenue_by_property_daily as rp 
    left join dim_prop as p on rp.property_code=p.property_code 
    
),
revpar as(
    select
        {{ dbt_utils.generate_surrogate_key(['property_code', 'stay_date']) }} as revpar_key,
        property_key,
        property_code,
        stay_date,
        total_rooms,
        ooo_rooms,
        rooms_available,
        rooms_sold,
        room_revenue_eur,
        avg_daily_rate_eur,
        occupancy_rate,
        revpar_eur,
        CURRENT_TIMESTAMP(2) as loaded_at
    from joined
),
final as(
    select * from revpar
)
select * from final