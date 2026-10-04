WITH source AS (
    SELECT * FROM {{ source('avenoirel_raw', 'folios') }}
),

renamed AS (
    SELECT
        folio_id::VARCHAR AS folio_id,
        confirmation_number::VARCHAR AS confirmation_number,
        window_number::INTEGER AS window_number,
        charge_type::VARCHAR AS charge_type,
        charge_description::VARCHAR AS charge_description,
        amount_local::FLOAT AS amount_local,
        currency_code::VARCHAR AS currency_code,
        amount_eur::FLOAT AS amount_eur,
        payment_method::VARCHAR AS payment_method,
        card_last4::VARCHAR AS card_last4,
        payee::VARCHAR AS payee,
        charge_date::DATE AS charge_date
    FROM source
    WHERE folio_id IS NOT NULL
)

SELECT * FROM renamed
