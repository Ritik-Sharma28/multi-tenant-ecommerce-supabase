-- ==============================================================================
-- ATOMIC ORDER CREATION (Sections 12, 13, 15)
-- Handles concurrency, locks inventory, calculates totals, and creates the order.
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.create_order(
    p_vendor_id UUID,
    p_shipping_address_id UUID,
    p_items JSONB -- Example: [{"variant_id": "uuid", "quantity": 2}]
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
    -- 1. Create the initial order shell
    INSERT INTO public.orders (user_id, vendor_id, shipping_address_id, subtotal, discount, tax, shipping_fee, total, status)
    VALUES (auth.uid(), p_vendor_id, p_shipping_address_id, 0, 0, 0, 0, 0, 'pending')
    RETURNING id INTO v_order_id;

    -- 2. Loop through cart items
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_variant_id := (v_item->>'variant_id')::UUID;
        v_quantity := (v_item->>'quantity')::INT;

        -- 3. CRITICAL CONCURRENCY LOCK (Section 13)
        -- 'FOR UPDATE' prevents race conditions by locking the row.
        SELECT quantity - reserved_quantity INTO v_available_qty
        FROM public.inventory
        WHERE variant_id = v_variant_id
        FOR UPDATE;

        IF v_available_qty IS NULL OR v_available_qty < v_quantity THEN
            RAISE EXCEPTION 'Insufficient inventory for variant %', v_variant_id;
        END IF;

        -- 4. Get price and deduct inventory
        SELECT price INTO v_unit_price FROM public.product_variants WHERE id = v_variant_id;

        UPDATE public.inventory
        SET quantity = quantity - v_quantity
        WHERE variant_id = v_variant_id;

        -- 5. Add order items
        INSERT INTO public.order_items (order_id, variant_id, quantity, unit_price, total_price)
        VALUES (v_order_id, v_variant_id, v_quantity, v_unit_price, v_quantity * v_unit_price);
    END LOOP;

    -- 6. Calculate total using the helper function we made earlier
    PERFORM public.calculate_order_total(v_order_id);

    -- 7. Create payment and finalize
    INSERT INTO public.payments (order_id, amount, payment_method, status)
    VALUES (v_order_id, (SELECT total FROM public.orders WHERE id = v_order_id), 'credit_card', 'completed');

    UPDATE public.orders SET status = 'completed' WHERE id = v_order_id;

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;