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
adr as(
    select
        {{ dbt_utils.generate_surrogate_key(['property_code', 'stay_date']) }} as adr_key,
        property_key,
        property_code,
        stay_date,
        rooms_sold,
        room_revenue_eur,
        avg_daily_rate_eur,
        CURRENT_TIMESTAMP(2) as loaded_at
    from joined
),
final as(
    select * from adr
)
select * from final