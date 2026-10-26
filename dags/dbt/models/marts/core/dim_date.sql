WITH dates AS (
    SELECT DATEADD(DAY, SEQ4(), '2022-01-01'::DATE) AS date_id
    FROM TABLE(GENERATOR(ROWCOUNT => 1096))
),

calendar AS (
    SELECT
        date_id,
        DAYOFWEEK(date_id) AS day_of_week,
        DAYNAME(date_id) AS day_name,
        CASE
            WHEN DAYOFWEEK(date_id) = 0 THEN TRUE
            WHEN DAYOFWEEK(date_id) = 6 THEN TRUE
            ELSE FALSE
        END AS is_weekend,
        WEEKOFYEAR(date_id) AS week_number,
        MONTH(date_id) AS month_number,
        MONTHNAME(date_id) AS month_name,
        QUARTER(date_id) AS quarter_number,
        YEAR(date_id) AS year_number,
        YEAR(date_id) AS fiscal_year,
        QUARTER(date_id) AS fiscal_quarter,
        CASE
            WHEN MONTH(date_id) IN (6, 7, 8, 9, 12) THEN 'HIGH'
            WHEN MONTH(date_id) IN (1, 2, 3, 11) THEN 'LOW'
            ELSE 'SHOULDER'
        END AS season,
        CASE
            WHEN MONTH(date_id) = 1 AND DAY(date_id) = 1 THEN TRUE
            WHEN MONTH(date_id) = 12 AND DAY(date_id) = 25 THEN TRUE
            WHEN MONTH(date_id) = 12 AND DAY(date_id) = 26 THEN TRUE
            ELSE FALSE
        END AS is_holiday
    FROM dates
)

SELECT * FROM calendar
