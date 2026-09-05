-- ==============================================================================
-- SECTION 6: CRUD OPERATIONS (crud.sql)
-- Demonstrates: INSERT, SELECT, UPDATE, DELETE, RETURNING, ON CONFLICT (UPSERT), 
--               Bulk INSERT, Bulk UPDATE, and Conditional UPDATE.
-- ==============================================================================

-- ==============================================================================
-- 1. BASIC CRUD WITH 'RETURNING'
-- ==============================================================================

-- INSERT with RETURNING: Create a new category and instantly get its generated UUID
WITH NewCategory AS (
    INSERT INTO public.categories (name, slug)
    VALUES ('Smart Home Devices', 'smart-home-devices')
    RETURNING id, name
)
-- Use the returned ID to immediately read the record (SELECT)
SELECT * FROM public.categories WHERE id = (SELECT id FROM NewCategory);

-- UPDATE with RETURNING: Modify the category name
WITH UpdatedCategory AS (
    UPDATE public.categories
    SET name = 'Smart Home & Automation'
    WHERE slug = 'smart-home-devices'
    RETURNING id, name
)
-- DELETE: Remove the category (cleanup)
DELETE FROM public.categories 
WHERE id = (SELECT id FROM UpdatedCategory);


-- ==============================================================================
-- 2. UPSERT (ON CONFLICT) 
-- Real-world scenario: "Add to Cart" functionality
-- ==============================================================================

WITH ActiveCart AS (
    SELECT id FROM public.carts LIMIT 1
),
AvailableVariant AS (
    SELECT id FROM public.product_variants LIMIT 1
)
-- UPSERT: If the item isn't in the cart, insert it. 
-- If it already exists (conflict on cart_id, variant_id), add to the existing quantity.
INSERT INTO public.cart_items (cart_id, variant_id, quantity)
SELECT c.id, v.id, 1
FROM ActiveCart c CROSS JOIN AvailableVariant v
ON CONFLICT (cart_id, variant_id) 
DO UPDATE SET 
    quantity = cart_items.quantity + EXCLUDED.quantity,
    updated_at = NOW()
RETURNING *;


-- ==============================================================================
-- 3. BULK INSERT
-- Real-world scenario: Vendor uploads a batch of new products
-- ==============================================================================

WITH TargetVendor AS (
    SELECT id FROM public.vendors WHERE status = 'active' LIMIT 1
),
TargetCategory AS (
    SELECT id FROM public.categories LIMIT 1
)
-- Inserting multiple rows in a single query block
INSERT INTO public.products (vendor_id, category_id, name, slug, description, base_price)
SELECT 
    v.id, 
    c.id, 
    new_products.name, 
    new_products.slug, 
    new_products.description, 
    new_products.price
FROM TargetVendor v CROSS JOIN TargetCategory c
CROSS JOIN (
    VALUES 
        ('Bulk Item A', 'bulk-item-a', 'Description A', 19.99::numeric),
        ('Bulk Item B', 'bulk-item-b', 'Description B', 29.99::numeric),
        ('Bulk Item C', 'bulk-item-c', 'Description C', 39.99::numeric)
) AS new_products(name, slug, description, price)
RETURNING id, name, base_price;


-- ==============================================================================
-- 4. BULK UPDATE & CONDITIONAL UPDATE
-- Real-world scenario: 10% price increase for active items, and order state machines
-- ==============================================================================

-- Bulk Update: Increase the price of all active products belonging to a specific vendor by 10%
UPDATE public.products
SET base_price = base_price * 1.10
WHERE vendor_id = (SELECT id FROM public.vendors LIMIT 1)
  AND status = 'active';

-- Conditional Update: Move orders to 'shipped' ONLY if they are currently 'pending'
-- This prevents accidental updates to 'failed' or 'completed' orders.
UPDATE public.orders
SET status = 'shipped'
WHERE vendor_id = (SELECT id FROM public.vendors LIMIT 1)
  AND status = 'pending'
RETURNING id, status;


-- ==============================================================================
-- 5. COMPREHENSIVE SELECT EXAMPLES
-- Demonstrating basic reads across required schema tables
-- ==============================================================================

-- Read Vendors and their Members
SELECT v.name, p.full_name, vm.role
FROM public.vendors v
JOIN public.vendor_members vm ON v.id = vm.vendor_id
JOIN public.profiles p ON vm.user_id = p.id
LIMIT 5;

-- Read Active Coupons and calculate their expiration status
SELECT 
    code, 
    discount_type, 
    discount_value, 
    expires_at,
    CASE 
        WHEN expires_at < NOW() THEN 'Expired'
        ELSE 'Active'
    END AS current_status
FROM public.coupons
WHERE active = TRUE;

-- Read Addresses formatted nicely
SELECT 
    address_line_1, 
    city, 
    state, 
    country, 
    postal_code,
    is_default
FROM public.addresses
WHERE is_default = TRUE
LIMIT 5;