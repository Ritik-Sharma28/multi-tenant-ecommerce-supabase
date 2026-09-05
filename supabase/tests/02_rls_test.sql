BEGIN;
SELECT plan(4);

-- Setup: Grab two distinct customer IDs
-- (In pgTAP, we simulate Supabase Auth by setting the jwt.claims local variable)
DO $$
DECLARE
    customer_a UUID := (SELECT id FROM public.profiles WHERE role = 'customer' LIMIT 1);
    customer_b UUID := (SELECT id FROM public.profiles WHERE role = 'customer' OFFSET 1 LIMIT 1);
BEGIN
    -- ==============================================================================
    -- TEST 1: Customer A can read their own orders
    -- ==============================================================================
    SET LOCAL role TO authenticated;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', customer_a)::text, true);
    
    -- This should succeed silently
    PERFORM 1 FROM public.orders WHERE user_id = customer_a;

    -- ==============================================================================
    -- TEST 2: Customer A CANNOT read Customer B's orders
    -- ==============================================================================
    -- Even if Customer A explicitly queries for Customer B's orders, RLS should return 0 rows.
    IF EXISTS (SELECT 1 FROM public.orders WHERE user_id = customer_b) THEN
        RAISE EXCEPTION 'RLS Failure: Customer A can see Customer B data!';
    END IF;
END $$;
SELECT pass('RLS successfully isolates Customer A and Customer B data');

-- ==============================================================================
-- TEST 3: Anonymous -> Private Data
-- ==============================================================================
SET LOCAL role TO anon;
-- Anonymous users shouldn't be able to see carts
SELECT is(
    (SELECT count(*)::int FROM public.carts),
    0,
    'Anonymous users should see 0 rows in the private carts table'
);

-- ==============================================================================
-- TEST 4: Anonymous -> Public Data
-- ==============================================================================
-- Anonymous users SHOULD be able to see active products
SELECT cmp_ok(
    (SELECT count(*)::int FROM public.products),
    '>',
    0,
    'Anonymous users should be able to view the public product catalog'
);

SELECT * FROM finish();
ROLLBACK;