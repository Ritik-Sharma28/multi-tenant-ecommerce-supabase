-- Create custom error types so our frontend knows exactly what went wrong
CREATE TYPE order_status AS ENUM ('pending', 'completed', 'failed');

CREATE OR REPLACE FUNCTION public.create_order(
    p_vendor_id UUID,
    p_shipping_address_id UUID,
    p_items JSONB -- An array of objects: [{"variant_id": "uuid", "quantity": 2}]
)
RETURNS UUID AS $$
DECLARE
    v_order_id UUID;
    v_item JSONB;
    v_variant_id UUID;
    v_quantity INT;
    v_unit_price NUMERIC;
    v_available_qty INT;
BEGIN
    -- ==============================================================
    -- 1. START THE TRANSACTION
    -- By putting this inside a PL/pgSQL function, it is automatically
    -- treated as a single atomic transaction. If ANY error is thrown,
    -- the entire thing rolls back automatically.
    -- ==============================================================

    -- Create the initial order shell (we will calculate the total later)
    INSERT INTO public.orders (user_id, vendor_id, shipping_address_id, subtotal, total, status)
    VALUES (auth.uid(), p_vendor_id, p_shipping_address_id, 0, 0, 'pending')
    RETURNING id INTO v_order_id;

    -- ==============================================================
    -- 2. LOOP THROUGH THE CART ITEMS
    -- ==============================================================
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_variant_id := (v_item->>'variant_id')::UUID;
        v_quantity := (v_item->>'quantity')::INT;

        -- ==============================================================
        -- 3. THE CRITICAL CONCURRENCY LOCK
        -- 'FOR UPDATE' tells Postgres to lock this specific row.
        -- No other transaction can read or modify this inventory row 
        -- until this function finishes!
        -- ==============================================================
        SELECT quantity - reserved_quantity INTO v_available_qty
        FROM public.inventory
        WHERE variant_id = v_variant_id
        FOR UPDATE;

        -- Check if we have enough stock AFTER acquiring the lock
        IF v_available_qty IS NULL OR v_available_qty < v_quantity THEN
            RAISE EXCEPTION 'Insufficient inventory for variant %', v_variant_id;
        END IF;

        -- 4. Get the current price of the item
        SELECT price INTO v_unit_price
        FROM public.product_variants
        WHERE id = v_variant_id;

        -- 5. Deduct from inventory
        UPDATE public.inventory
        SET quantity = quantity - v_quantity
        WHERE variant_id = v_variant_id;

        -- 6. Add the item to the order
        INSERT INTO public.order_items (order_id, variant_id, quantity, unit_price, total_price)
        VALUES (v_order_id, v_variant_id, v_quantity, v_unit_price, v_quantity * v_unit_price);
    END LOOP;

    -- ==============================================================
    -- 7. FINALIZE THE ORDER
    -- Call the helper function we made in the previous step
    -- ==============================================================
    PERFORM public.calculate_order_total(v_order_id);

    -- 8. Create a dummy payment record (assuming successful card charge)
    INSERT INTO public.payments (order_id, amount, payment_method, status)
    VALUES (v_order_id, (SELECT total FROM public.orders WHERE id = v_order_id), 'credit_card', 'completed');

    -- Update order status to completed
    UPDATE public.orders
    SET status = 'completed'
    WHERE id = v_order_id;

    -- If we get to this line, everything worked! The transaction commits.
    RETURN v_order_id;

EXCEPTION
    WHEN OTHERS THEN
        -- If any RAISE EXCEPTION was triggered, or any SQL error happened,
        -- Postgres automatically rolls back all INSERTS and UPDATES in this block.
        RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;