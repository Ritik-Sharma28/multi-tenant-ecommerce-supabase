-- ==============================================================================
-- SECTION 7: SQL JOIN ASSESSMENT (joins.sql)
-- Demonstrates all required JOIN types and specific assignment queries[cite: 4].
-- ==============================================================================

-- ==============================================================================
-- QUERY 1: Multiple-table JOIN
-- Requirement: Return Customer -> Order -> Order Item -> Product -> Vendor[cite: 4]
-- ==============================================================================
SELECT 
    c.full_name AS customer_name,
    o.id AS order_id,
    o.status AS order_status,
    oi.quantity,
    pr.name AS product_name,
    v.name AS vendor_name
FROM public.profiles c
INNER JOIN public.orders o ON c.id = o.user_id
INNER JOIN public.order_items oi ON o.id = oi.order_id
INNER JOIN public.product_variants pv ON oi.variant_id = pv.id
INNER JOIN public.products pr ON pv.product_id = pr.id
INNER JOIN public.vendors v ON pr.vendor_id = v.id
LIMIT 20;


-- ==============================================================================
-- QUERY 2: LEFT JOIN & Anti JOIN
-- Requirement: Find vendors with zero products[cite: 4]
-- ==============================================================================
SELECT 
    v.id AS vendor_id,
    v.name AS vendor_name,
    v.status
FROM public.vendors v
LEFT JOIN public.products p ON v.id = p.vendor_id
WHERE p.id IS NULL;


-- ==============================================================================
-- QUERY 3: NOT EXISTS (Anti JOIN via Subquery)
-- Requirement: Find products that have never been purchased[cite: 4]
-- ==============================================================================
SELECT 
    p.id AS product_id,
    p.name AS product_name,
    p.slug
FROM public.products p
WHERE NOT EXISTS (
    SELECT 1 
    FROM public.order_items oi
    INNER JOIN public.product_variants pv ON oi.variant_id = pv.id
    WHERE pv.product_id = p.id
);


-- ==============================================================================
-- DEMO: Many-to-many JOIN
-- Connecting Users to Vendors via the vendor_members bridge table[cite: 4]
-- ==============================================================================
SELECT 
    p.full_name AS employee_name,
    vm.role AS permissions_role,
    v.name AS vendor_name
FROM public.profiles p
INNER JOIN public.vendor_members vm ON p.id = vm.user_id
INNER JOIN public.vendors v ON vm.vendor_id = v.id
LIMIT 10;


-- ==============================================================================
-- DEMO: SELF JOIN
-- Querying the category hierarchy (Parent -> Child) within the same table[cite: 4]
-- ==============================================================================
SELECT 
    child.name AS sub_category,
    parent.name AS parent_category
FROM public.categories child
LEFT JOIN public.categories parent ON child.parent_id = parent.id
LIMIT 10;


-- ==============================================================================
-- DEMO: Semi JOIN (EXISTS)
-- Find users who have an active cart, without duplicating the user row[cite: 4]
-- ==============================================================================
SELECT 
    p.full_name,
    p.email
FROM public.profiles p
WHERE EXISTS (
    SELECT 1 
    FROM public.carts c 
    WHERE c.user_id = p.id
)
LIMIT 10;


-- ==============================================================================
-- DEMO: RIGHT JOIN
-- Ensures all categories are returned, even if they have no products[cite: 4]
-- ==============================================================================
SELECT 
    c.name AS category_name,
    p.name AS product_name
FROM public.products p
RIGHT JOIN public.categories c ON p.category_id = c.id
LIMIT 15;


-- ==============================================================================
-- DEMO: FULL OUTER JOIN
-- Returns all carts and all cart items, exposing orphaned items or empty carts[cite: 4]
-- ==============================================================================
SELECT 
    c.id AS cart_id,
    ci.variant_id,
    ci.quantity
FROM public.carts c
FULL OUTER JOIN public.cart_items ci ON c.id = ci.cart_id
LIMIT 15;


-- ==============================================================================
-- DEMO: CROSS JOIN
-- Creates a Cartesian product matrix of active vendors and active coupons[cite: 4]
-- ==============================================================================
SELECT 
    v.name AS vendor_name,
    c.code AS coupon_code
FROM (SELECT name FROM public.vendors WHERE status = 'active' LIMIT 3) v
CROSS JOIN (SELECT code FROM public.coupons WHERE active = true LIMIT 3) c;