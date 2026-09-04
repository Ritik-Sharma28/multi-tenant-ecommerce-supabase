-- ==============================================================================
-- CHALLENGE 5: CONSECUTIVE MONTHLY SPENDING INCREASES
-- Requirement: Find customers whose spending increased for three consecutive months[cite: 1]
-- Demonstrates: Deep LAG() Window Functions, Gap Detection
-- ==============================================================================
WITH MonthlySpend AS (
    SELECT 
        user_id,
        DATE_TRUNC('month', created_at) AS spend_month,
        SUM(total) AS total_spend
    FROM public.orders
    WHERE status = 'completed'
    GROUP BY user_id, DATE_TRUNC('month', created_at)
),
HistoricalComparison AS (
    SELECT 
        user_id,
        spend_month AS m3_date,
        total_spend AS m3_spend,
        
        LAG(total_spend, 1) OVER (PARTITION BY user_id ORDER BY spend_month) AS m2_spend,
        LAG(spend_month, 1) OVER (PARTITION BY user_id ORDER BY spend_month) AS m2_date,
        
        LAG(total_spend, 2) OVER (PARTITION BY user_id ORDER BY spend_month) AS m1_spend,
        LAG(spend_month, 2) OVER (PARTITION BY user_id ORDER BY spend_month) AS m1_date
    FROM MonthlySpend
)
SELECT DISTINCT
    h.user_id,
    p.full_name
FROM HistoricalComparison h
JOIN public.profiles p ON h.user_id = p.id
WHERE 
    h.m3_spend > h.m2_spend 
    AND h.m2_spend > h.m1_spend
    AND h.m3_date = h.m2_date + INTERVAL '1 month'
    AND h.m2_date = h.m1_date + INTERVAL '1 month';