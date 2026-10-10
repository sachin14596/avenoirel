WITH avenir AS (
    SELECT * FROM {{ ref('stg_avenir_tier_history') }}
),

result AS (
    SELECT
        h.history_id,
        h.member_number,
        h.previous_tier,
        h.new_tier,
        h.change_type,
        h.effective_date,
        h.status_points_at_change,
        lag(h.effective_date)
            OVER (PARTITION BY h.member_number ORDER BY h.effective_date ASC)
            AS prev_change_date,
        lead(h.new_tier)
            OVER (PARTITION BY h.member_number ORDER BY h.effective_date ASC)
            AS next_tier,
        h.effective_date
        - (
            lag(h.effective_date)
                OVER (
                    PARTITION BY h.member_number ORDER BY h.effective_date ASC
                )
        ) AS days_at_tier,
        coalesce(row_number() OVER (PARTITION BY h.member_number ORDER BY h.effective_date DESC) = 1, FALSE)
            AS is_latest_record
    FROM avenir AS h
),

final AS (
    SELECT * FROM result
)

SELECT * FROM final
