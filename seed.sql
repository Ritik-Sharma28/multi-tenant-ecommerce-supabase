
-- Generate 50 unique categories
INSERT INTO public.categories (id, name, slug)
SELECT 
    gen_random_uuid(),
    'Category ' || i || ' ' || substr(md5(random()::text), 1, 4),
    'category-' || i || '-' || substr(md5(random()::text), 1, 4)
FROM generate_series(1, 50) AS i;

-- Generate 1,000 Auth Users and map them to Public Profiles
WITH new_auth AS (
    INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password, created_at, updated_at)
    SELECT 
        '00000000-0000-0000-0000-000000000000',
        gen_random_uuid(),
        'authenticated',
        'authenticated',
        'testuser_' || i || '_' || substr(md5(random()::text), 1, 6) || '@example.com',
        'mock_hash_for_testing',
        now(),
        now()
    FROM generate_series(1, 1000) AS i
    RETURNING id
)
INSERT INTO public.profiles (id, full_name, phone, role)
SELECT 
    id,
    'Mock User ' || substr(md5(id::text), 1, 6),
    '+1555' || lpad(floor(random() * 10000000)::text, 7, '0'),
    (ARRAY['customer', 'customer', 'customer', 'vendor_employee', 'vendor_owner'])[floor(random() * 5) + 1]::public.user_role
FROM new_auth;

-- Generate 50 Vendors using a subset of users
INSERT INTO public.vendors (id, name, slug, description, owner_id, status)
SELECT 
    gen_random_uuid(),
    'Vendor ' || s.i || ' ' || substr(md5(random()::text), 1, 4),
    'vendor-' || s.i || '-' || substr(md5(random()::text), 1, 4),
    'High-grade generated mock supplier providing extensive inventory.',
    u.id,
    (ARRAY['active', 'active', 'inactive'])[floor(random() * 3) + 1]
FROM generate_series(1, 50) AS s(i)
JOIN (SELECT id, ROW_NUMBER() OVER () as rn FROM public.profiles LIMIT 50) u ON u.rn = s.i;

-- Generate 1,000 Default Addresses (1 per user)
INSERT INTO public.addresses (id, user_id, address_line_1, city, state, country, postal_code, is_default)
SELECT 
    gen_random_uuid(),
    id,
    floor(random() * 9999 + 1)::text || ' Generated Ave',
    (ARRAY['New York', 'Los Angeles', 'London', 'Tokyo', 'Berlin'])[floor(random() * 5) + 1],
    (ARRAY['NY', 'CA', 'LDN', 'TKY', 'BE'])[floor(random() * 5) + 1],
    'Global',
    floor(random() * 90000 + 10000)::text,
    TRUE
FROM public.profiles;
-- Generate 5,000 Products
INSERT INTO public.products (id, vendor_id, category_id, name, slug, description, base_price, status)
SELECT 
    gen_random_uuid(),
    v.id,
    c.id,
    'Product ' || s.i || '-' || upper(substr(md5(random()::text), 1, 5)),
    'product-' || s.i || '-' || substr(md5(random()::text), 1, 8),
    'Auto-generated multi-tenant product featuring specification variant ' || substr(md5(random()::text), 1, 6),
    (random() * 800 + 10)::numeric(12,2),
    (ARRAY['active', 'active', 'active', 'draft'])[floor(random() * 4) + 1]
FROM generate_series(1, 5000) AS s(i)
JOIN (SELECT id, ROW_NUMBER() OVER () as rn FROM public.vendors) v ON v.rn = (s.i % 50) + 1
JOIN (SELECT id, ROW_NUMBER() OVER () as rn FROM public.categories) c ON c.rn = (s.i % 50) + 1;

-- Generate 10,000 Product Variants (2 per product) with JSONB logic
INSERT INTO public.product_variants (id, product_id, sku, name, price, attributes)
SELECT 
    gen_random_uuid(),
    p.id,
    'SKU-' || s.i || '-' || upper(substr(md5(random()::text), 1, 8)),
    'Variant Config ' || (s.i % 5 + 1),
    p.base_price + (random() * 100)::numeric(12,2),
    jsonb_build_object(
        'color', (ARRAY['black', 'white', 'silver', 'red', 'blue'])[floor(random() * 5) + 1], 
        'size', (ARRAY['S', 'M', 'L', 'XL', '256GB'])[floor(random() * 5) + 1]
    )
FROM generate_series(1, 10000) AS s(i)
JOIN (SELECT id, base_price, ROW_NUMBER() OVER () as rn FROM public.products) p ON p.rn = (s.i % 5000) + 1;

-- Generate 10,000 Inventory Records (Strictly 1 per variant)
INSERT INTO public.inventory (variant_id, quantity, reserved_quantity)
SELECT 
    id,
    floor(random() * 1000 + 50)::int,
    floor(random() * 20)::int
FROM public.product_variants;
-- Generate 5,000 Orders
INSERT INTO public.orders (id, user_id, vendor_id, shipping_address_id, status, subtotal, discount, tax, shipping_fee, total, created_at)
SELECT 
    gen_random_uuid(),
    u.id,
    v.id,
    a.id,
    (ARRAY['completed', 'completed', 'pending', 'shipped', 'failed'])[floor(random() * 5) + 1],
    (random() * 1500 + 50)::numeric(12,2),
    0, 
    15.00, 
    10.00, 
    0, -- We initialize total at 0, next step simulates the calculation
    now() - (random() * interval '365 days') -- Spreads orders randomly over the past year
FROM generate_series(1, 5000) AS s(i)
JOIN (SELECT id, ROW_NUMBER() OVER () as rn FROM public.profiles) u ON u.rn = (s.i % 1000) + 1
JOIN (SELECT id, ROW_NUMBER() OVER () as rn FROM public.vendors) v ON v.rn = (s.i % 50) + 1
JOIN (SELECT id, ROW_NUMBER() OVER () as rn FROM public.addresses) a ON a.rn = (s.i % 1000) + 1;

-- Generate 15,000 Order Items via CTE to lock in math calculations
WITH base_items AS (
    SELECT 
        gen_random_uuid() as id,
        o.id as order_id,
        v.id as variant_id,
        floor(random() * 4 + 1)::int as quantity,
        v.price as unit_price
    FROM generate_series(1, 15000) AS s(i)
    JOIN (SELECT id, ROW_NUMBER() OVER () as rn FROM public.orders) o ON o.rn = (s.i % 5000) + 1
    JOIN (SELECT id, price, ROW_NUMBER() OVER () as rn FROM public.product_variants) v ON v.rn = (s.i % 10000) + 1
)
INSERT INTO public.order_items (id, order_id, variant_id, quantity, unit_price, total_price)
SELECT 
    id, 
    order_id, 
    variant_id, 
    quantity, 
    unit_price, 
    (quantity * unit_price) -- Calculates line total accurately
FROM base_items;

-- Correct order totals based on subtotal + tax + shipping (Simulation of calculate_order_total RPC)
UPDATE public.orders
SET total = subtotal + tax + shipping_fee - discount;
-- Generate 200 Vendor Members (approx 4 per vendor)
WITH MemberSubset AS (
    SELECT id, ROW_NUMBER() OVER () as rn 
    FROM public.profiles 
    WHERE role != 'customer' 
    LIMIT 200
)
INSERT INTO public.vendor_members (vendor_id, user_id, role)
SELECT 
    v.id,
    u.id,
    (ARRAY['vendor_employee', 'vendor_manager', 'vendor_employee'])[floor(random() * 3) + 1]::public.user_role
FROM generate_series(1, 200) AS s(i)
JOIN (SELECT id, ROW_NUMBER() OVER () as rn FROM public.vendors) v ON v.rn = (s.i % 50) + 1
JOIN MemberSubset u ON u.rn = s.i
ON CONFLICT (vendor_id, user_id) DO NOTHING;

-- Generate 10,000 Product Images (exactly 2 images per product)
INSERT INTO public.product_images (product_id, storage_path, alt_text, display_order)
SELECT 
    id,
    'product-images/' || id || '/image-' || s.i || '.jpg',
    'High-resolution showcase image ' || s.i || ' for ' || name,
    s.i
FROM public.products
CROSS JOIN generate_series(1, 2) AS s(i);
-- Generate Payments (1 for every 'completed' order)
INSERT INTO public.payments (order_id, transaction_id, amount, status, payment_method)
SELECT 
    id,
    'txn_' || upper(md5(random()::text)),
    total,
    'completed',
    (ARRAY['credit_card', 'paypal', 'apple_pay', 'google_pay'])[floor(random() * 4) + 1]
FROM public.orders
WHERE status = 'completed';

-- Generate ~1,500 Reviews (using a CTE to extract actual purchased products)
WITH OrderedProducts AS (
    SELECT 
        o.id AS order_id, 
        o.user_id, 
        pv.product_id, 
        ROW_NUMBER() OVER () as rn
    FROM public.orders o
    JOIN public.order_items oi ON o.id = oi.order_id
    JOIN public.product_variants pv ON oi.variant_id = pv.id
    WHERE o.status = 'completed'
    LIMIT 1500
)
INSERT INTO public.reviews (product_id, user_id, order_id, rating, title, comment)
SELECT 
    product_id,
    user_id,
    order_id,
    floor(random() * 5 + 1)::int, -- Ensures rating is between 1 and 5
    'Review ' || substr(md5(random()::text), 1, 6),
    'Auto-generated review testing analytical queries and aggregate functions.'
FROM OrderedProducts;

-- Generate 150 Coupons (3 per vendor)
INSERT INTO public.coupons (vendor_id, code, discount_type, discount_value, minimum_order_amount, starts_at, expires_at, usage_limit, active)
SELECT 
    id,
    'SAVE' || floor(random() * 90 + 10)::text || upper(substr(md5(random()::text), 1, 4)),
    (ARRAY['fixed', 'percentage'])[floor(random() * 2) + 1],
    (random() * 15 + 5)::numeric(12,2),
    (random() * 100 + 20)::numeric(12,2),
    now() - interval '10 days',
    now() + interval '90 days',
    500,
    true
FROM public.vendors
CROSS JOIN generate_series(1, 3);
-- Generate 200 Active Carts
INSERT INTO public.carts (user_id)
SELECT id FROM public.profiles WHERE role = 'customer' LIMIT 200;

-- Generate 600 Cart Items
WITH CartSubset AS (SELECT id, ROW_NUMBER() OVER () as rn FROM public.carts),
     VariantSubset AS (SELECT id, ROW_NUMBER() OVER () as rn FROM public.product_variants LIMIT 600)
INSERT INTO public.cart_items (cart_id, variant_id, quantity)
SELECT 
    c.id,
    v.id,
    floor(random() * 3 + 1)::int
FROM generate_series(1, 600) AS s(i)
JOIN CartSubset c ON c.rn = (s.i % 200) + 1
JOIN VariantSubset v ON v.rn = s.i
ON CONFLICT (cart_id, variant_id) DO NOTHING;

-- Generate 1,000 System Notifications (1 per user)
INSERT INTO public.notifications (user_id, type, title, message, data)
SELECT 
    id,
    'system_alert',
    'Welcome to the Platform',
    'Your account and demo data have been successfully provisioned.',
    '{"source": "seed_script"}'::jsonb
FROM public.profiles;

-- Trigger the audit logs organically by increasing the price of 500 products by $1.00
UPDATE public.products 
SET base_price = base_price + 1.00 
WHERE id IN (
    SELECT id FROM public.products LIMIT 500
);

-- ==============================================================================
-- PART 1: INJECT ENGINEERED "WHALE" CUSTOMERS (To satisfy Challenge 2 & 5)
-- ==============================================================================

-- 1. Isolate 5 specific customers to act as our high-value "Whales"
WITH WhaleCustomers AS (
    SELECT id, ROW_NUMBER() OVER () as rn FROM public.profiles WHERE role = 'customer' LIMIT 5
),
-- 2. Isolate 3 specific vendors
TargetVendors AS (
    SELECT id, ROW_NUMBER() OVER () as rn FROM public.vendors LIMIT 3
),
-- 3. Get one valid product variant from each of those vendors
TargetVariants AS (
    SELECT 
        v.id as vendor_id, 
        pv.id as variant_id, 
        pv.price,
        ROW_NUMBER() OVER (PARTITION BY v.id) as vendor_rn
    FROM TargetVendors v
    JOIN public.products p ON p.vendor_id = v.id
    JOIN public.product_variants pv ON pv.product_id = p.id
),
-- 4. Create 15 massive orders (3 per Whale, from 3 different vendors, in the last 30 days)
NewOrders AS (
    INSERT INTO public.orders (user_id, vendor_id, shipping_address_id, status, subtotal, discount, tax, shipping_fee, total, created_at)
    SELECT 
        wc.id,
        tv.id,
        (SELECT id FROM public.addresses WHERE user_id = wc.id LIMIT 1),
        'completed',
        15000.00, -- Massive subtotal to guarantee they beat the global average
        0, 150, 0, 15150.00,
        NOW() - (s.i * interval '5 days') -- Guarantees recent purchases (last 15 days)
    FROM WhaleCustomers wc
    CROSS JOIN TargetVendors tv
    CROSS JOIN generate_series(1, 1) AS s(i) -- 1 order per vendor per whale
    RETURNING id, vendor_id
)
-- 5. Attach expensive items to these specific orders
INSERT INTO public.order_items (order_id, variant_id, quantity, unit_price, total_price)
SELECT 
    no.id,
    tv.variant_id,
    10, -- High quantity
    tv.price,
    (10 * tv.price)
FROM NewOrders no
JOIN TargetVariants tv ON tv.vendor_id = no.vendor_id AND tv.vendor_rn = 1;


-- ==============================================================================
-- PART 2: SEED THE REMAINING 9 EMPTY TABLES 
-- ==============================================================================

-- 1. VENDOR MEMBERS (Internal Staff)
WITH MemberSubset AS (
    SELECT id, ROW_NUMBER() OVER () as rn FROM public.profiles WHERE role != 'customer' LIMIT 200
)
INSERT INTO public.vendor_members (vendor_id, user_id, role)
SELECT 
    v.id,
    u.id,
    (ARRAY['vendor_employee', 'vendor_manager', 'vendor_employee'])[floor(random() * 3) + 1]::public.user_role
FROM generate_series(1, 200) AS s(i)
JOIN (SELECT id, ROW_NUMBER() OVER () as rn FROM public.vendors) v ON v.rn = (s.i % 50) + 1
JOIN MemberSubset u ON u.rn = s.i
ON CONFLICT (vendor_id, user_id) DO NOTHING;

-- 2. PRODUCT IMAGES (2 per product)
INSERT INTO public.product_images (product_id, storage_path, alt_text, display_order)
SELECT 
    id,
    'product-images/' || id || '/image-' || s.i || '.jpg',
    'High-resolution showcase image ' || s.i || ' for ' || name,
    s.i
FROM public.products
CROSS JOIN generate_series(1, 2) AS s(i);

-- 3. PAYMENTS (Match every completed order, including our new Whale orders)
INSERT INTO public.payments (order_id, transaction_id, amount, status, payment_method)
SELECT 
    id,
    'txn_' || upper(md5(id::text)),
    total,
    'completed',
    (ARRAY['credit_card', 'paypal', 'apple_pay', 'google_pay'])[floor(random() * 4) + 1]
FROM public.orders
WHERE status = 'completed'
ON CONFLICT (transaction_id) DO NOTHING;

-- 4. REVIEWS (Only for products actually purchased by the user)
WITH OrderedProducts AS (
    SELECT 
        o.id AS order_id, 
        o.user_id, 
        pv.product_id, 
        ROW_NUMBER() OVER () as rn
    FROM public.orders o
    JOIN public.order_items oi ON o.id = oi.order_id
    JOIN public.product_variants pv ON oi.variant_id = pv.id
    WHERE o.status = 'completed'
    LIMIT 2000
)
INSERT INTO public.reviews (product_id, user_id, order_id, rating, title, comment)
SELECT 
    product_id,
    user_id,
    order_id,
    floor(random() * 5 + 1)::int,
    'Review ' || substr(md5(random()::text), 1, 6),
    'Auto-generated review testing analytical queries and aggregate functions.'
FROM OrderedProducts;

-- 5. COUPONS (3 distinct discount codes per vendor)
INSERT INTO public.coupons (vendor_id, code, discount_type, discount_value, minimum_order_amount, starts_at, expires_at, usage_limit, active)
SELECT 
    id,
    'SAVE' || s.i || upper(substr(md5(random()::text), 1, 6)),
    (ARRAY['fixed', 'percentage'])[floor(random() * 2) + 1],
    (random() * 15 + 5)::numeric(12,2),
    (random() * 100 + 20)::numeric(12,2),
    now() - interval '10 days',
    now() + interval '90 days',
    500,
    true
FROM public.vendors
CROSS JOIN generate_series(1, 3) AS s(i)
ON CONFLICT (vendor_id, code) DO NOTHING;

-- 6. CARTS (Active browsing sessions for 200 users)
INSERT INTO public.carts (user_id)
SELECT id FROM public.profiles WHERE role = 'customer' LIMIT 200
ON CONFLICT (user_id) DO NOTHING;

-- 7. CART ITEMS (Link random inventory variants to the open carts)
WITH CartSubset AS (SELECT id, ROW_NUMBER() OVER () as rn FROM public.carts),
     VariantSubset AS (SELECT id, ROW_NUMBER() OVER () as rn FROM public.product_variants LIMIT 600)
INSERT INTO public.cart_items (cart_id, variant_id, quantity)
SELECT 
    c.id,
    v.id,
    floor(random() * 3 + 1)::int
FROM generate_series(1, 600) AS s(i)
JOIN CartSubset c ON c.rn = (s.i % 200) + 1
JOIN VariantSubset v ON v.rn = s.i
ON CONFLICT (cart_id, variant_id) DO NOTHING;

-- 8. NOTIFICATIONS (System alerts for all users)
INSERT INTO public.notifications (user_id, type, title, message, data)
SELECT 
    id,
    'system_alert',
    'Welcome to the Platform',
    'Your account and demo data have been successfully provisioned.',
    '{"source": "seed_script"}'::jsonb
FROM public.profiles;

-- 9. AUDIT LOGS (Triggered automatically by updating product prices)
-- We simulate a bulk price increase on 500 products, which will fire 
-- the 'process_audit_log' trigger and organically populate the audit_logs table.
UPDATE public.products 
SET base_price = base_price + 2.50 
WHERE id IN (
    SELECT id FROM public.products LIMIT 500
);
-- ==============================================================================
-- 1. CATEGORIES (Fills the 0-row categories table)
-- ==============================================================================
INSERT INTO public.categories (id, name, slug)
SELECT 
    gen_random_uuid(), 
    'Category ' || i, 
    'category-' || i || '-' || substr(md5(random()::text), 1, 4)
FROM generate_series(1, 50) AS i;

-- ==============================================================================
-- 2. PRODUCTS (Links new products to existing Vendors and new Categories)
-- ==============================================================================
WITH VendorList AS (SELECT id, ROW_NUMBER() OVER () as rn FROM public.vendors),
     CategoryList AS (SELECT id, ROW_NUMBER() OVER () as rn FROM public.categories)
INSERT INTO public.products (id, vendor_id, category_id, name, slug, description, base_price, status)
SELECT 
    gen_random_uuid(),
    v.id,
    c.id,
    'Product ' || s.i || ' ' || upper(substr(md5(random()::text), 1, 4)),
    'product-' || s.i || '-' || substr(md5(random()::text), 1, 8),
    'Auto-generated description for product ' || s.i,
    (random() * 900 + 10)::numeric(12,2),
    (ARRAY['active', 'active', 'active', 'draft'])[floor(random() * 4) + 1]
FROM generate_series(1, 5000) AS s(i)
JOIN VendorList v ON v.rn = (s.i % (SELECT COUNT(*) FROM VendorList)) + 1
JOIN CategoryList c ON c.rn = (s.i % (SELECT COUNT(*) FROM CategoryList)) + 1;

-- ==============================================================================
-- 3. PRODUCT VARIANTS (Fills the 0-row variants table with JSONB attributes)
-- ==============================================================================
WITH ProductList AS (SELECT id, base_price, ROW_NUMBER() OVER () as rn FROM public.products)
INSERT INTO public.product_variants (id, product_id, sku, name, price, attributes)
SELECT 
    gen_random_uuid(),
    p.id,
    'SKU-' || s.i || '-' || upper(substr(md5(random()::text), 1, 6)),
    'Variant Config ' || (s.i % 3 + 1),
    p.base_price + (random() * 50)::numeric(12,2),
    jsonb_build_object(
        'color', (ARRAY['black', 'white', 'silver', 'red', 'blue'])[floor(random() * 5) + 1], 
        'size', (ARRAY['S', 'M', 'L', 'XL', '256GB'])[floor(random() * 5) + 1]
    )
FROM generate_series(1, 10000) AS s(i)
JOIN ProductList p ON p.rn = (s.i % (SELECT COUNT(*) FROM ProductList)) + 1;

-- ==============================================================================
-- 4. INVENTORY & PRODUCT IMAGES (Fills both 0-row tables)
-- ==============================================================================
INSERT INTO public.inventory (variant_id, quantity, reserved_quantity)
SELECT id, floor(random() * 500 + 50)::int, floor(random() * 10)::int
FROM public.product_variants;

INSERT INTO public.product_images (product_id, storage_path, alt_text, display_order)
SELECT id, 'product-images/' || id || '/img-' || s.i || '.jpg', 'Showcase ' || s.i, s.i
FROM public.products
CROSS JOIN generate_series(1, 2) AS s(i);

-- ==============================================================================
-- 5. ORDER ITEMS (Links existing 5,015 Orders to new Variants securely)
-- ==============================================================================
WITH OrderList AS (SELECT id, ROW_NUMBER() OVER () as rn FROM public.orders),
     VariantList AS (SELECT id, price, ROW_NUMBER() OVER () as rn FROM public.product_variants),
     BaseItems AS (
         SELECT 
             gen_random_uuid() as item_id,
             o.id as order_id,
             v.id as variant_id,
             floor(random() * 4 + 1)::int as qty,
             v.price as unit_price
         FROM generate_series(1, 15000) AS s(i)
         JOIN OrderList o ON o.rn = (s.i % (SELECT COUNT(*) FROM OrderList)) + 1
         JOIN VariantList v ON v.rn = (s.i % (SELECT COUNT(*) FROM VariantList)) + 1
     )
INSERT INTO public.order_items (id, order_id, variant_id, quantity, unit_price, total_price)
SELECT item_id, order_id, variant_id, qty, unit_price, (qty * unit_price)
FROM BaseItems;

-- 5b. Correct the existing Order subtotals based on the newly attached items
WITH OrderTotals AS (
    SELECT order_id, SUM(total_price) as sum_total
    FROM public.order_items
    GROUP BY order_id
)
UPDATE public.orders o
SET subtotal = ot.sum_total,
    total = ot.sum_total + o.tax + o.shipping_fee - o.discount
FROM OrderTotals ot
WHERE o.id = ot.order_id;

-- ==============================================================================
-- 6. CART ITEMS & REVIEWS (Fills remaining 0-row relational tables)
-- ==============================================================================
WITH CartList AS (SELECT id, ROW_NUMBER() OVER () as rn FROM public.carts),
     VariantList AS (SELECT id, ROW_NUMBER() OVER () as rn FROM public.product_variants)
INSERT INTO public.cart_items (cart_id, variant_id, quantity)
SELECT c.id, v.id, floor(random() * 3 + 1)::int
FROM generate_series(1, 600) AS s(i)
JOIN CartList c ON c.rn = (s.i % (SELECT COUNT(*) FROM CartList)) + 1
JOIN VariantList v ON v.rn = (s.i % (SELECT COUNT(*) FROM VariantList)) + 1
ON CONFLICT (cart_id, variant_id) DO NOTHING;

WITH OrderedProducts AS (
    SELECT o.id AS order_id, o.user_id, pv.product_id, ROW_NUMBER() OVER () as rn
    FROM public.orders o
    JOIN public.order_items oi ON o.id = oi.order_id
    JOIN public.product_variants pv ON oi.variant_id = pv.id
    WHERE o.status = 'completed'
    LIMIT 2000
)
INSERT INTO public.reviews (product_id, user_id, order_id, rating, title, comment)
SELECT product_id, user_id, order_id, floor(random() * 5 + 1)::int, 'Great Product', 'Generated review.'
FROM OrderedProducts;

-- ==============================================================================
-- 7. AUDIT LOGS (Organically triggered)
-- ==============================================================================
-- Bumping the price of 500 products organically forces the database to write 
-- 500 rows to the audit_logs table via the existing trigger function.
UPDATE public.products 
SET base_price = base_price + 1.25 
WHERE id IN (SELECT id FROM public.products LIMIT 500);

-- ==============================================================================
-- 8. ENGINEERED VARIETY DATA ("Whale" Cohort for Analytics Testing)
-- ==============================================================================
WITH WhaleUsers AS (
    SELECT id, ROW_NUMBER() OVER () as rn FROM public.profiles WHERE role = 'customer' LIMIT 5
),
TargetVendors AS (
    SELECT id, ROW_NUMBER() OVER () as rn FROM public.vendors LIMIT 3
),
TargetVariants AS (
    SELECT v.id as vendor_id, pv.id as variant_id, pv.price, ROW_NUMBER() OVER (PARTITION BY v.id) as vendor_rn
    FROM TargetVendors v
    JOIN public.products p ON p.vendor_id = v.id
    JOIN public.product_variants pv ON pv.product_id = p.id
),
NewOrders AS (
    INSERT INTO public.orders (user_id, vendor_id, shipping_address_id, status, subtotal, discount, tax, shipping_fee, total, created_at)
    SELECT 
        wu.id, tv.id, (SELECT id FROM public.addresses WHERE user_id = wu.id LIMIT 1),
        'completed', 25000.00, 0, 250, 0, 25250.00, NOW() - (s.i * interval '2 days')
    FROM WhaleUsers wu
    CROSS JOIN TargetVendors tv
    CROSS JOIN generate_series(1, 1) AS s(i)
    RETURNING id, vendor_id
)
INSERT INTO public.order_items (order_id, variant_id, quantity, unit_price, total_price)
SELECT no.id, tv.variant_id, 15, tv.price, (15 * tv.price)
FROM NewOrders no
JOIN TargetVariants tv ON tv.vendor_id = no.vendor_id AND tv.vendor_rn = 1;