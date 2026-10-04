WITH source AS (
    SELECT * FROM {{ source('avenoirel_raw', 'cancellations') }}
),

renamed AS (
    SELECT
        cancellation_id::VARCHAR AS cancellation_id,
        confirmation_number::VARCHAR AS confirmation_number,
        cancellation_date::DATE AS cancellation_date,
        reason_code::VARCHAR AS reason_code,
        reason_group::VARCHAR AS reason_group,
        days_before_checkin::INTEGER AS days_before_checkin,
        cancellation_window::VARCHAR AS cancellation_window,
        revenue_at_risk::FLOAT AS revenue_at_risk,
        currency_code::VARCHAR AS currency_code
    FROM source
    WHERE cancellation_id IS NOT NULL
)

SELECT * FROM renamed
