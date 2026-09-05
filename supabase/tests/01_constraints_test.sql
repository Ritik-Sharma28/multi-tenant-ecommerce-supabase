BEGIN;
SELECT plan(5);

-- 1. Test Negative Price
SELECT throws_ok(
    $$ INSERT INTO public.products (vendor_id, category_id, name, slug, base_price) 
       VALUES ((SELECT id FROM vendors LIMIT 1), (SELECT id FROM categories LIMIT 1), 'Test', 'test-1', -10.00) $$,
    'new row for relation "products" violates check constraint "products_base_price_check"',
    'Database should reject negative product prices'
);

-- 2. Test Negative Inventory
SELECT throws_ok(
    $$ INSERT INTO public.inventory (variant_id, quantity) 
       VALUES ((SELECT id FROM product_variants LIMIT 1), -5) $$,
    'new row for relation "inventory" violates check constraint "inventory_quantity_check"',
    'Database should reject negative inventory'
);

-- 3. Test Invalid Rating
SELECT throws_ok(
    $$ INSERT INTO public.reviews (product_id, user_id, order_id, rating) 
       VALUES ((SELECT id FROM products LIMIT 1), (SELECT id FROM profiles LIMIT 1), (SELECT id FROM orders LIMIT 1), 6) $$,
    'new row for relation "reviews" violates check constraint "reviews_rating_check"',
    'Database should reject ratings outside the 1-5 range'
);

-- 4. Test Duplicate SKU
SELECT throws_ok(
    $$ INSERT INTO public.product_variants (product_id, sku, name, price) 
       VALUES ((SELECT id FROM products LIMIT 1), (SELECT sku FROM product_variants LIMIT 1), 'Test Variant', 10.00) $$,
    'duplicate key value violates unique constraint "product_variants_sku_key"',
    'Database should reject duplicate SKUs'
);

-- 5. Test Duplicate Coupon
SELECT throws_ok(
    $$ INSERT INTO public.coupons (vendor_id, code, discount_type, discount_value, starts_at) 
       VALUES ((SELECT vendor_id FROM coupons LIMIT 1), (SELECT code FROM coupons LIMIT 1), 'fixed', 10, NOW()) $$,
    'duplicate key value violates unique constraint "coupons_vendor_id_code_key"',
    'Database should reject duplicate coupon codes for the same vendor'
);

SELECT * FROM finish();
ROLLBACK;