-- ==============================================================================
-- SECTION 8: SUBQUERIES (subqueries.sql)
-- Demonstrates: Scalar, Correlated, EXISTS, NOT EXISTS, IN, NOT IN[cite: 4]
-- ==============================================================================

-- ==============================================================================
-- 1. CORRELATED SUBQUERY (Requested Example)
-- Requirement: Find products whose price is above their category's average price[cite: 4].
-- Why it's correlated: The subquery references 'p.category_id' from the outer query,
-- meaning it must recalculate the average for every single row.
-- ==============================================================================
SELECT 
    p.name AS product_name,
    p.base_price,
    c.name AS category_name
FROM public.products p
JOIN public.categories c ON p.category_id = c.id
WHERE p.base_price > (
    SELECT AVG(p2.base_price)
    FROM public.products p2
    WHERE p2.category_id = p.category_id
)
ORDER BY c.name, p.base_price DESC;


-- ==============================================================================
-- 2. SCALAR SUBQUERY
-- A subquery in the SELECT clause that returns exactly one column and one row.
-- Here, we fetch the total lifetime platform sales to calculate a vendor's market share.
-- ==============================================================================
SELECT 
    v.name AS vendor_name,
    SUM(o.total) AS vendor_revenue,
    (SELECT SUM(total) FROM public.orders WHERE status = 'completed') AS total_platform_revenue,
    ROUND((SUM(o.total) / (SELECT SUM(total) FROM public.orders WHERE status = 'completed')) * 100, 2) AS market_share_percentage
FROM public.vendors v
JOIN public.orders o ON v.id = o.vendor_id
WHERE o.status = 'completed'
GROUP BY v.id, v.name
ORDER BY vendor_revenue DESC
LIMIT 10;


-- ==============================================================================
-- 3. EXISTS
-- Much faster than IN for large datasets. Returns TRUE the moment it finds a single match.
-- Find customers who have abandoned a cart (have items in cart, but no completed orders today).
-- ==============================================================================
SELECT 
    p.full_name AS customer_name,
    p.email
FROM public.profiles p
WHERE p.role = 'customer'
  AND EXISTS (
      -- Check if they have an active cart with items
      SELECT 1 
      FROM public.carts c 
      JOIN public.cart_items ci ON c.id = ci.cart_id 
      WHERE c.user_id = p.id
  )
  AND NOT EXISTS (
      -- Ensure they haven't actually checked out today
      SELECT 1 
      FROM public.orders o 
      WHERE o.user_id = p.id 
        AND o.created_at >= DATE_TRUNC('day', NOW())
  );


-- ==============================================================================
-- 4. NOT EXISTS
-- Anti-join strategy to find orphaned or unused data.
-- Find categories that currently have absolutely no products assigned to them.
-- ==============================================================================
SELECT 
    c.name AS empty_category,
    c.slug
FROM public.categories c
WHERE NOT EXISTS (
    SELECT 1 
    FROM public.products p 
    WHERE p.category_id = c.id
);


-- ==============================================================================
-- 5. IN (Subquery returning a list)
-- Find all product variants belonging to the top 3 most expensive base products.
-- ==============================================================================
SELECT 
    pv.sku,
    pv.name AS variant_name,
    pv.price AS variant_price
FROM public.product_variants pv
WHERE pv.product_id IN (
    -- Subquery returns a list of 3 specific product IDs
    SELECT id 
    FROM public.products 
    ORDER BY base_price DESC 
    LIMIT 3
);


-- ==============================================================================
-- 6. NOT IN
-- Find all vendors who have NOT had any order failures (high reliability vendors).
-- ==============================================================================
SELECT 
    id, 
    name AS reliable_vendor
FROM public.vendors
WHERE status = 'active'
  AND id NOT IN (
      -- Subquery returns a list of vendor IDs that have failed orders
      SELECT vendor_id 
      FROM public.orders 
      WHERE status = 'failed'
  );