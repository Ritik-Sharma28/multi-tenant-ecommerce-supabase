-- ==============================================================================
-- CHALLENGE 1: TOP 3 PRODUCTS PER VENDOR BY REVENUE
-- Demonstrates: Window Functions, CTEs, Aggregations, JOINs
-- ==============================================================================

WITH ProductRevenue AS (
    -- 1. Calculate total revenue for each product
    SELECT 
        p.vendor_id,
        v.name AS vendor_name,
        p.id AS product_id,
        p.name AS product_name,
        SUM(oi.total_price) AS total_revenue
    FROM public.products p
    INNER JOIN public.vendors v ON p.vendor_id = v.id
    INNER JOIN public.product_variants pv ON p.id = pv.product_id  -- FIXED: Added variant join
    INNER JOIN public.order_items oi ON pv.id = oi.variant_id      -- FIXED: Link to variant
    INNER JOIN public.orders o ON oi.order_id = o.id
    WHERE o.status = 'completed'
    GROUP BY p.vendor_id, v.name, p.id, p.name
),
RankedProducts AS (
    -- 2. Rank products within each vendor's partition
    SELECT 
        vendor_name,
        product_name,
        total_revenue,
        DENSE_RANK() OVER (PARTITION BY vendor_id ORDER BY total_revenue DESC) as revenue_rank
    FROM ProductRevenue
)
-- 3. Filter to only show the top 3
SELECT vendor_name, product_name, total_revenue, revenue_rank
FROM RankedProducts
WHERE revenue_rank <= 3
ORDER BY vendor_name ASC, revenue_rank ASC;