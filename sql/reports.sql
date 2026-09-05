-- ==============================================================================
-- SECTION 9 & 18: EXECUTIVE REPORTS (reports.sql)
-- Demonstrates: Querying Materialized Views, generating dashboard metrics, 
-- and summarizing complex platform data.
-- ==============================================================================

-- 1. MATERIALIZED VIEW REPORT (Section 18)
-- Fast retrieval of aggregated historical data without calculating it on the fly.
-- This view was populated during migrations and is scheduled to refresh nightly via pg_cron.
SELECT 
    vendor_name,
    sales_month,
    total_orders,
    items_sold,
    revenue
FROM public.monthly_vendor_sales
ORDER BY sales_month DESC, revenue DESC
LIMIT 20;

-- 2. PLATFORM HEALTH REPORT
-- Combines multiple table counts into a single JSON object for an admin dashboard.
SELECT jsonb_build_object(
    'total_users', (SELECT COUNT(*) FROM public.profiles),
    'active_vendors', (SELECT COUNT(*) FROM public.vendors WHERE status = 'active'),
    'total_products', (SELECT COUNT(*) FROM public.products WHERE status = 'active'),
    'total_sales_volume', (SELECT SUM(total) FROM public.orders WHERE status = 'completed')
) AS platform_health_metrics;

-- 3. LOW INVENTORY ALERT REPORT
-- Identifies products that are running critically low on available stock.
SELECT 
    v.name AS vendor_name,
    p.name AS product_name,
    pv.name AS variant_name,
    pv.sku,
    (i.quantity - i.reserved_quantity) AS available_stock
FROM public.inventory i
JOIN public.product_variants pv ON i.variant_id = pv.id
JOIN public.products p ON pv.product_id = p.id
JOIN public.vendors v ON p.vendor_id = v.id
WHERE (i.quantity - i.reserved_quantity) < 10
ORDER BY available_stock ASC;

-- 4. COUPON USAGE REPORT
-- Evaluates which marketing campaigns are driving the most traffic.
SELECT 
    v.name AS vendor_name,
    c.code,
    c.discount_type,
    c.discount_value,
    c.usage_count,
    c.usage_limit,
    CASE 
        WHEN c.usage_limit IS NULL THEN 'Unlimited'
        WHEN c.usage_count >= c.usage_limit THEN 'Depleted'
        ELSE ((c.usage_limit - c.usage_count)::text || ' remaining')
    END AS capacity_status
FROM public.coupons c
JOIN public.vendors v ON c.vendor_id = v.id
ORDER BY c.usage_count DESC;