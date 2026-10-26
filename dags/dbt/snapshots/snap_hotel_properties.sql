{% snapshot snap_hotel_properties %}

{{
    config(
        target_schema='snapshot',
        unique_key='property_code',
        strategy='timestamp',
        updated_at='created_at'

    )
}}

SELECT * FROM {{ ref('stg_hotel_properties') }}
{% endsnapshot %}