{{ config(severity='warn', tags=['reconciliation']) }}

-- Known data issue: for a small set of sold reservations the nights column differs from
-- check_out_date - check_in_date. Reported as a warning, not fixed in staging.
SELECT
    confirmation_number,
    nights,
    DATEDIFF('day', check_in_date, check_out_date) AS nights_from_dates
FROM {{ ref('stg_hotel_reservations') }}
WHERE
    booking_status IN ('CHECKED_IN', 'CHECKED_OUT', 'NO_SHOW')
    AND nights != DATEDIFF('day', check_in_date, check_out_date)
