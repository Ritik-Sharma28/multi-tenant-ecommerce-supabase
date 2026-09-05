-- ==============================================================================
-- CHALLENGE 7: CUSTOMER WHO BOUGHT MOST EXPENSIVE PRODUCT PER VENDOR
-- Demonstrates: Analytical Window Functions (RANK), CTEs, Multi-table JOINs
-- ==============================================================================

WITH RankedPurchases AS (
    -- Step 1 & 2: Build the detailed purchase history and rank them per vendor
    SELECT 
        v.name AS vendor_name,
        p.full_name AS customer_name,
        pr.name AS product_name,
        oi.unit_price AS purchase_price,
        RANK() OVER (
            PARTITION BY o.vendor_id 
            ORDER BY oi.unit_price DESC
        ) as price_rank
    FROM public.order_items oi
    JOIN public.orders o ON oi.order_id = o.id
    JOIN public.profiles p ON o.user_id = p.id
    JOIN public.vendors v ON o.vendor_id = v.id
    JOIN public.product_variants pv ON oi.variant_id = pv.id
    JOIN public.products pr ON pv.product_id = pr.id
    WHERE o.status = 'completed'
)
-- Step 3: Filter for the #1 ranked purchase in each partition
SELECT 
    vendor_name,
    customer_name,
    product_name,
    purchase_price
FROM RankedPurchases
WHERE price_rank = 1
ORDER BY vendor_name ASC;