-- ==============================================================================
-- SECTION 11: WINDOW FUNCTIONS (window_functions.sql)
-- Requirement: Demonstrate ROW_NUMBER(), RANK(), DENSE_RANK(), LAG(), LEAD(), 
-- SUM() OVER, AVG() OVER, PARTITION BY[cite: 4].
-- ==============================================================================

-- 1. Top 3 products per vendor (RANK / DENSE_RANK / PARTITION BY)
WITH ProductRevenue AS (
    SELECT 
        p.vendor_id,
        p.name AS product_name,
        SUM(oi.total_price) AS revenue
    FROM public.products p
    JOIN public.product_variants pv ON p.id = pv.product_id
    JOIN public.order_items oi ON pv.id = oi.variant_id
    JOIN public.orders o ON oi.order_id = o.id
    WHERE o.status = 'completed'
    GROUP BY p.vendor_id, p.name
),
RankedProducts AS (
    SELECT 
        v.name AS vendor_name,
        pr.product_name,
        pr.revenue,
        DENSE_RANK() OVER (PARTITION BY pr.vendor_id ORDER BY pr.revenue DESC) AS rank
    FROM ProductRevenue pr
    JOIN public.vendors v ON pr.vendor_id = v.id
)
SELECT * FROM RankedProducts WHERE rank <= 3;


-- 2. Customer spending ranking (ROW_NUMBER)
-- ROW_NUMBER forces a unique sequential integer even if totals are identical.
SELECT 
    p.full_name,
    SUM(o.total) AS total_spent,
    ROW_NUMBER() OVER (ORDER BY SUM(o.total) DESC) AS absolute_spending_rank
FROM public.profiles p
JOIN public.orders o ON p.id = o.user_id
WHERE o.status = 'completed'
GROUP BY p.id, p.full_name;


-- 3. Monthly revenue growth (LAG / LEAD)
-- LAG looks backwards to the previous row. LEAD looks forward to the next row.
WITH MonthlyStats AS (
    SELECT 
        DATE_TRUNC('month', created_at) AS mth,
        SUM(total) AS revenue
    FROM public.orders
    WHERE status = 'completed'
    GROUP BY DATE_TRUNC('month', created_at)
)
SELECT 
    mth AS current_month,
    revenue AS current_revenue,
    LAG(revenue, 1) OVER (ORDER BY mth) AS previous_month_revenue,
    LEAD(revenue, 1) OVER (ORDER BY mth) AS next_month_revenue
FROM MonthlyStats;


-- 4. Running revenue total & Moving Averages (SUM OVER / AVG OVER)
-- Calculates a cumulative sum over time, and a rolling average.
WITH DailySales AS (
    SELECT 
        DATE_TRUNC('day', created_at) AS sale_date,
        SUM(total) AS daily_total
    FROM public.orders
    WHERE status = 'completed'
    GROUP BY DATE_TRUNC('day', created_at)
)
SELECT 
    sale_date,
    daily_total,
    SUM(daily_total) OVER (ORDER BY sale_date) AS cumulative_running_total,
    AVG(daily_total) OVER (ORDER BY sale_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS rolling_7_day_avg
FROM DailySales;