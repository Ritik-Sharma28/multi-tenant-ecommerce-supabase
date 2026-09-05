-- ==============================================================================
-- CHALLENGE 6: MOST POPULAR CATEGORY PER VENDOR
-- Demonstrates: Multi-table JOINs, Aggregate grouping, Partitioned Window Functions
-- ==============================================================================

WITH CategorySales AS (
    -- Step 1 & 2: Calculate total quantity sold for every vendor-category combination
    SELECT 
        p.vendor_id,
        v.name AS vendor_name,
        p.category_id,
        c.name AS category_name,
        SUM(oi.quantity) AS total_sold
    FROM public.order_items oi
    JOIN public.orders o ON oi.order_id = o.id
    JOIN public.product_variants pv ON oi.variant_id = pv.id
    JOIN public.products p ON pv.product_id = p.id
    JOIN public.vendors v ON p.vendor_id = v.id
    JOIN public.categories c ON p.category_id = c.id
    WHERE o.status = 'completed'
    GROUP BY p.vendor_id, v.name, p.category_id, c.name
),
RankedCategories AS (
    -- Step 3: Rank the categories independently within each vendor's partition
    SELECT 
        vendor_name,
        category_name,
        total_sold,
        RANK() OVER (PARTITION BY vendor_id ORDER BY total_sold DESC) as popularity_rank
    FROM CategorySales
)
-- Step 4: Extract only the top-ranked category per vendor
SELECT 
    vendor_name,
    category_name AS most_popular_category,
    total_sold
FROM RankedCategories
WHERE popularity_rank = 1
ORDER BY vendor_name ASC;