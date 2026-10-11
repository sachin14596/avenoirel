WITH reservations AS (
    SELECT * FROM {{ ref('stg_hotel_reservations') }}
),

rate_codes AS (
    SELECT * FROM {{ ref('rate_codes') }}
),

joined AS (
    SELECT
        r.confirmation_number,
        r.property_code,
        r.guest_profile_id,
        r.booking_date,
        r.booking_status,
        r.rate_code,
        r.rate_channel,
        r.rate_flexibility,
        r.includes_breakfast,
        r.market_segment,
        r.is_direct_booking,
        c.rate_category,
        c.description AS rate_description,
        FIRST_VALUE(r.rate_channel) OVER (
            PARTITION BY r.guest_profile_id ORDER BY r.booking_date ASC
        ) AS first_booking_channel,
        COUNT(r.confirmation_number) OVER (
            PARTITION BY r.guest_profile_id
        ) AS guest_booking_count,
        ROW_NUMBER() OVER (
            PARTITION BY r.guest_profile_id ORDER BY r.booking_date
        ) = 1 AS is_first_booking
    FROM reservations AS r
    LEFT JOIN rate_codes AS c ON r.rate_code = c.rate_code
),

enriched AS (
    SELECT
        *,
        CASE
            WHEN first_booking_channel = rate_channel THEN 'CONSISTENT'
            WHEN
                first_booking_channel != 'DIRECT' AND rate_channel = 'DIRECT'
                THEN 'OTA_TO_DIRECT'
            WHEN
                first_booking_channel = 'DIRECT' AND rate_channel != 'DIRECT'
                THEN 'DIRECT_TO_OTA'
            ELSE 'CHANNEL_CHANGE'
        END AS channel_shift
    FROM joined
),

final AS (
    SELECT * FROM enriched
)

SELECT * FROM final
