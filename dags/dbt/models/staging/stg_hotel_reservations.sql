WITH source AS (
    SELECT * FROM {{ source('avenoirel_raw', 'reservations') }}
),

renamed AS (
    SELECT
        confirmation_number::VARCHAR AS confirmation_number,
        property_code::VARCHAR AS property_code,
        guest_profile_id::VARCHAR AS guest_profile_id,
        room_type_id::VARCHAR AS room_type_id,
        room_type_booked::VARCHAR AS room_type_booked,
        room_type_to_charge::VARCHAR AS room_type_to_charge,
        was_upgraded::BOOLEAN AS was_upgraded,
        room_number::VARCHAR AS room_number,
        rate_code::VARCHAR AS rate_code,
        rate_channel::VARCHAR AS rate_channel,
        rate_flexibility::VARCHAR AS rate_flexibility,
        includes_breakfast::BOOLEAN AS includes_breakfast,
        market_segment::VARCHAR AS market_segment,
        booking_date::DATE AS booking_date,
        check_in_date::DATE AS check_in_date,
        check_out_date::DATE AS check_out_date,
        nights::INTEGER AS nights,
        adults::INTEGER AS adults,
        children::INTEGER AS children,
        booking_status::VARCHAR AS booking_status,
        nightly_rate::FLOAT AS nightly_rate,
        total_cost::FLOAT AS total_cost,
        local_currency::VARCHAR AS local_currency,
        travel_agent::VARCHAR AS travel_agent,
        tars_external_ref::VARCHAR AS tars_external_ref,
        gds_record_locator::VARCHAR AS gds_record_locator,
        is_direct_booking::BOOLEAN AS is_direct_booking,
        member_number::VARCHAR AS member_number,
        actual_checkin_at::TIMESTAMP AS actual_checkin_at,
        is_duplicate_reservation::BOOLEAN AS is_duplicate_reservation,
        is_test_record::BOOLEAN AS is_test_record,
        has_invalid_date_sequence::BOOLEAN AS has_invalid_date_sequence
    FROM source
    WHERE confirmation_number IS NOT NULL
)

SELECT * FROM renamed
