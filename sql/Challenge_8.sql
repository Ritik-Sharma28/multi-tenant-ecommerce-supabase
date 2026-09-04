-- ==============================================================================
-- CHALLENGE 8: PRODUCTS WITH DECLINING SALES FOR 3 CONSECUTIVE PERIODS
-- Demonstrates: Deep Window Functions (LAG), Time-Series Gap Detection, 
--               Multi-Level CTEs
-- ==============================================================================

WITH MonthlyProductSales AS (
    -- Step 1 & 2: Calculate total quantity sold per product, per month
    SELECT 
        p.id AS product_id,
        p.name AS product_name,
        DATE_TRUNC('month', o.created_at) AS sales_month,
        SUM(oi.quantity) AS total_sold
    FROM public.products p
    JOIN public.product_variants pv ON p.id = pv.product_id
    JOIN public.order_items oi ON pv.id = oi.variant_id
    JOIN public.orders o ON oi.order_id = o.id
    WHERE o.status = 'completed'
    GROUP BY p.id, p.name, DATE_TRUNC('month', o.created_at)
),
SalesHistory AS (
    -- Step 3: Shift the previous 3 months of data onto the current month's row
    SELECT 
        product_id,
        product_name,
        
        sales_month AS m4_date,
        total_sold AS m4_sold,
        
        LAG(total_sold, 1) OVER (PARTITION BY product_id ORDER BY sales_month) AS m3_sold,
        LAG(sales_month, 1) OVER (PARTITION BY product_id ORDER BY sales_month) AS m3_date,
        
        LAG(total_sold, 2) OVER (PARTITION BY product_id ORDER BY sales_month) AS m2_sold,
        LAG(sales_month, 2) OVER (PARTITION BY product_id ORDER BY sales_month) AS m2_date,
        
        LAG(total_sold, 3) OVER (PARTITION BY product_id ORDER BY sales_month) AS m1_sold,
        LAG(sales_month, 3) OVER (PARTITION BY product_id ORDER BY sales_month) AS m1_date
    FROM MonthlyProductSales
)
-- Step 4: Evaluate the declines and ensure no gaps exist in the timeline
SELECT DISTINCT
    product_name
FROM SalesHistory
WHERE 
    -- Condition A: Strict consecutive decline across 4 periods (3 drops)
    m4_sold < m3_sold 
    AND m3_sold < m2_sold 
    AND m2_sold < m1_sold
    
    -- Condition B: Timeline is perfectly sequential (no 0-sale skipped months)
    AND m4_date = m3_date + INTERVAL '1 month'
    AND m3_date = m2_date + INTERVAL '1 month'
    AND m2_date = m1_date + INTERVAL '1 month'
ORDER BY product_name;