-- ==============================================================================
-- SECTION 9: COMMON TABLE EXPRESSIONS (cte.sql)
-- Requirement: Demonstrate multiple CTE queries including Vendor revenue, 
-- Customer LTV, Monthly revenue, Product sales, and Purchase history.
-- ==============================================================================

-- 1. Vendor Revenue
WITH VendorSales AS (
    SELECT 
        vendor_id, 
        SUM(total) AS total_revenue,
        COUNT(id) AS total_orders
    FROM public.orders
    WHERE status = 'completed'
    GROUP BY vendor_id
)
SELECT v.name, vs.total_revenue, vs.total_orders 
FROM public.vendors v
JOIN VendorSales vs ON v.id = vs.vendor_id;


-- 2. Customer Lifetime Value (CLV)
WITH CustomerLTV AS (
    SELECT 
        user_id, 
        SUM(total) AS lifetime_value
    FROM public.orders
    WHERE status = 'completed'
    GROUP BY user_id
)
SELECT p.full_name, c.lifetime_value 
FROM public.profiles p
JOIN CustomerLTV c ON p.id = c.user_id
ORDER BY c.lifetime_value DESC
LIMIT 10;


-- 3. Monthly Revenue (Platform-wide)
WITH MonthlyAggregates AS (
    SELECT 
        DATE_TRUNC('month', created_at) AS sales_month,
        SUM(total) AS monthly_revenue
    FROM public.orders
    WHERE status = 'completed'
    GROUP BY DATE_TRUNC('month', created_at)
)
SELECT sales_month, monthly_revenue 
FROM MonthlyAggregates 
ORDER BY sales_month DESC;


-- 4. Product Sales (Total units sold per product)
WITH VariantSales AS (
    SELECT 
        variant_id, 
        SUM(quantity) AS units_sold
    FROM public.order_items oi
    JOIN public.orders o ON oi.order_id = o.id
    WHERE o.status = 'completed'
    GROUP BY variant_id
)
SELECT 
    p.name AS product_name, 
    pv.name AS variant_name, 
    COALESCE(vs.units_sold, 0) AS total_units_sold
FROM public.product_variants pv
JOIN public.products p ON pv.product_id = p.id
LEFT JOIN VariantSales vs ON pv.id = vs.variant_id
ORDER BY total_units_sold DESC
LIMIT 10;


-- 5. Customer Purchase History
WITH UserOrders AS (
    SELECT 
        user_id, 
        id AS order_id, 
        total, 
        created_at
    FROM public.orders
    WHERE status = 'completed'
)
SELECT 
    p.full_name, 
    uo.order_id, 
    uo.total, 
    uo.created_at
FROM public.profiles p
JOIN UserOrders uo ON p.id = uo.user_id
WHERE p.role = 'customer'
ORDER BY p.full_name, uo.created_at DESC;