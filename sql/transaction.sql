-- ==============================================================================
-- SECTION 12: TRANSACTIONS (transactions.sql)
-- Requirement: Create an atomic order creation process demonstrating ROLLBACK 
-- and preventing partial orders.
-- ==============================================================================

-- 1. SUCCESSFUL ATOMIC TRANSACTION
-- This block executes entirely or fails entirely.
DO $$ 
DECLARE
    v_user_id UUID;
    v_vendor_id UUID;
    v_variant_id UUID;
    v_address_id UUID;
    v_order_id UUID;
    v_price NUMERIC;
BEGIN
    -- Setup mock variables for demonstration
    SELECT id INTO v_user_id FROM public.profiles WHERE role = 'customer' LIMIT 1;
    SELECT id INTO v_vendor_id FROM public.vendors WHERE status = 'active' LIMIT 1;
    SELECT id INTO v_address_id FROM public.addresses WHERE user_id = v_user_id LIMIT 1;
    SELECT pv.id, pv.price INTO v_variant_id, v_price 
    FROM public.product_variants pv 
    JOIN public.inventory i ON pv.id = i.variant_id 
    WHERE (i.quantity - i.reserved_quantity) > 0 LIMIT 1;

    -- [START TRANSACTION]
    -- Note: PL/pgSQL DO blocks act as implicit transactions.
    
    -- Step A: Validate Inventory and apply Row-Level Lock
    PERFORM id FROM public.inventory WHERE variant_id = v_variant_id FOR UPDATE;

    -- Step B: Deduct Inventory
    UPDATE public.inventory 
    SET quantity = quantity - 1 
    WHERE variant_id = v_variant_id;

    -- Step C: Create Order Shell
    INSERT INTO public.orders (user_id, vendor_id, shipping_address_id, subtotal, total, status)
    VALUES (v_user_id, v_vendor_id, v_address_id, v_price, v_price + 10, 'pending')
    RETURNING id INTO v_order_id;

    -- Step D: Create Order Items
    INSERT INTO public.order_items (order_id, variant_id, quantity, unit_price, total_price)
    VALUES (v_order_id, v_variant_id, 1, v_price, v_price);

    -- Step E: Create Payment
    INSERT INTO public.payments (order_id, transaction_id, amount, status, payment_method)
    VALUES (v_order_id, 'txn_demo_' || floor(random()*1000), v_price + 10, 'completed', 'credit_card');

    -- Step F: Finalize Order
    UPDATE public.orders SET status = 'completed' WHERE id = v_order_id;

    -- [COMMIT IS IMPLICIT UPON SUCCESSFUL COMPLETION OF THE BLOCK]
END $$;


-- ==============================================================================
-- 2. FORCED FAILURE AND ROLLBACK (Section 38 Testing Requirement)
-- Requirement: Force a failure in the middle of order creation to verify no 
-- partial order remains[cite: 4].
-- ==============================================================================

DO $$ 
DECLARE
    v_user_id UUID;
    v_vendor_id UUID;
    v_variant_id UUID;
    v_address_id UUID;
    v_order_id UUID;
BEGIN
    SELECT id INTO v_user_id FROM public.profiles WHERE role = 'customer' LIMIT 1;
    SELECT id INTO v_vendor_id FROM public.vendors WHERE status = 'active' LIMIT 1;
    SELECT id INTO v_address_id FROM public.addresses WHERE user_id = v_user_id LIMIT 1;

    -- 1. Insert the order successfully
    INSERT INTO public.orders (user_id, vendor_id, shipping_address_id, subtotal, total, status)
    VALUES (v_user_id, v_vendor_id, v_address_id, 100, 100, 'pending')
    RETURNING id INTO v_order_id;

    -- 2. Force an intentional failure (e.g., trying to insert an invalid product ID)
    INSERT INTO public.order_items (order_id, variant_id, quantity, unit_price, total_price)
    VALUES (v_order_id, '00000000-0000-0000-0000-000000000000'::UUID, 1, 100, 100);

EXCEPTION
    WHEN OTHERS THEN
        -- [AUTOMATIC ROLLBACK TRIGGERED]
        -- PostgreSQL immediately halts execution and wipes the previously inserted 
        -- order shell from the database. The database state reverts to exactly 
        -- how it was before the DO block started.
        RAISE NOTICE 'Transaction failed and rolled back due to error: %', SQLERRM;
END $$;