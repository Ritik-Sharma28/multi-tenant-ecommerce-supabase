-- ==============================================================================
-- CHALLENGE 4: VENDOR REVENUE GROWTH AND RANKING
-- Requirement: Current month revenue, Previous month revenue, Growth %, Vendor rank[cite: 1]
-- Demonstrates: Conditional Aggregation, Date Math, Ranking Window Functions
-- ==============================================================================
WITH TargetDates AS (
    SELECT 
        DATE_TRUNC('month', NOW()) AS current_month,
        DATE_TRUNC('month', NOW() - INTERVAL '1 month') AS previous_month
),
VendorStats AS (
    SELECT 
        v.id AS vendor_id,
        v.name AS vendor_name,
        COALESCE(SUM(CASE WHEN DATE_TRUNC('month', o.created_at) = t.current_month THEN o.total ELSE 0 END), 0) AS current_revenue,
        COALESCE(SUM(CASE WHEN DATE_TRUNC('month', o.created_at) = t.previous_month THEN o.total ELSE 0 END), 0) AS previous_revenue
    FROM public.vendors v
    CROSS JOIN TargetDates t
    LEFT JOIN public.orders o ON v.id = o.vendor_id 
        AND o.status = 'completed'
        AND o.created_at >= t.previous_month 
        AND o.created_at < t.current_month + INTERVAL '1 month'
    GROUP BY v.id, v.name
)
SELECT 
    vendor_name,
    current_revenue,
    previous_revenue,
    CASE 
        WHEN previous_revenue = 0 THEN NULL 
        ELSE ROUND(((current_revenue - previous_revenue) / previous_revenue) * 100, 2)
    END AS growth_percentage,
    RANK() OVER (ORDER BY current_revenue DESC) AS vendor_rank
FROM VendorStats
ORDER BY vendor_rank;