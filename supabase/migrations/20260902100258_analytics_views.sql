-- ==============================================================
-- 1. LIVE VIEW: Customer Order Summary
-- Requirement: customer, order_count, total_spent, average_order_value, last_order_date
-- ==============================================================
CREATE OR REPLACE VIEW public.customer_order_summary AS
SELECT 
    p.id AS customer_id,
    p.full_name AS customer_name,
    COUNT(o.id) AS order_count,
    COALESCE(SUM(o.total), 0) AS total_spent,
    COALESCE(AVG(o.total), 0) AS average_order_value,
    MAX(o.created_at) AS last_order_date
FROM 
    public.profiles p
LEFT JOIN 
    public.orders o ON p.id = o.user_id AND o.status = 'completed'
WHERE 
    p.role = 'customer'
GROUP BY 
    p.id, p.full_name;


-- ==============================================================
-- 2. LIVE VIEW: Vendor Dashboard
-- Requirement: vendor, product_count, order_count, revenue, average_order_value
-- ==============================================================
CREATE OR REPLACE VIEW public.vendor_dashboard AS
SELECT 
    v.id AS vendor_id,
    v.name AS vendor_name,
    COUNT(DISTINCT p.id) AS product_count,
    COUNT(DISTINCT o.id) AS order_count,
    COALESCE(SUM(o.total), 0) AS revenue,
    COALESCE(AVG(o.total), 0) AS average_order_value
FROM 
    public.vendors v
LEFT JOIN 
    public.products p ON v.id = p.vendor_id
LEFT JOIN 
    public.orders o ON v.id = o.vendor_id AND o.status = 'completed'
GROUP BY 
    v.id, v.name;


-- ==============================================================
-- 3. MATERIALIZED VIEW: Monthly Vendor Sales
-- Requirement: vendor, month, orders, items_sold, revenue
-- ==============================================================
CREATE MATERIALIZED VIEW public.monthly_vendor_sales AS
SELECT 
    v.id AS vendor_id,
    v.name AS vendor_name,
    DATE_TRUNC('month', o.created_at) AS sales_month,
    COUNT(DISTINCT o.id) AS total_orders,
    COALESCE(SUM(oi.quantity), 0) AS items_sold,
    COALESCE(SUM(o.total), 0) AS revenue
FROM 
    public.vendors v
JOIN 
    public.orders o ON v.id = o.vendor_id AND o.status = 'completed'
JOIN 
    public.order_items oi ON o.id = oi.order_id
GROUP BY 
    v.id, v.name, DATE_TRUNC('month', o.created_at)
WITH DATA;

-- Create a unique index on the materialized view so it can be refreshed concurrently (without locking the table)
CREATE UNIQUE INDEX idx_monthly_vendor_sales ON public.monthly_vendor_sales (vendor_id, sales_month);