-- ==============================================================================
-- CHALLENGE 2: HIGH-VALUE RECENT CUSTOMERS
-- Demonstrates: CTEs, Aggregate Comparisons, HAVING clause, Date Math
-- ==============================================================================

WITH CustomerTotals AS (
    -- Step 1: Calculate the lifetime spend of every customer
    -- We only count completed orders to reflect actual spend.
    SELECT 
        user_id, 
        SUM(total) as lifetime_spend
    FROM public.orders
    WHERE status = 'completed'
    GROUP BY user_id
),
GlobalAverage AS (
    -- Step 2: Calculate the global average customer lifetime value (CLV)
    -- This condenses the previous CTE into a single numeric value in memory.
    SELECT 
        AVG(lifetime_spend) as global_avg_spend
    FROM CustomerTotals
)
-- Step 3: The Main Query
-- Aggregate the data per user and apply our four specific conditions
SELECT 
    o.user_id,
    p.full_name,
    COUNT(o.id) AS total_orders,
    SUM(o.total) AS total_spent,
    COUNT(DISTINCT o.vendor_id) AS distinct_vendors,
    MAX(o.created_at) AS last_order_date
FROM public.orders o
JOIN public.profiles p ON o.user_id = p.id
WHERE o.status = 'completed'
GROUP BY o.user_id, p.full_name
HAVING 
    -- Condition 1: Have more than 3 orders
    COUNT(o.id) > 3 
    
    -- Condition 2: Purchased from at least 2 vendors
    AND COUNT(DISTINCT o.vendor_id) >= 2 
    
    -- Condition 3: Purchased within the last 90 days
    AND MAX(o.created_at) >= NOW() - INTERVAL '90 days'
    
    -- Condition 4: Spend more than average
    -- We pull the single scalar value from our GlobalAverage CTE
    AND SUM(o.total) > (SELECT global_avg_spend FROM GlobalAverage)
ORDER BY 
    total_spent DESC;