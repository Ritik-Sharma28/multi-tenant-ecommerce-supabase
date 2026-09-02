CREATE OR REPLACE FUNCTION public.calculate_order_total(p_order_id UUID)
RETURNS NUMERIC AS $$
DECLARE
    v_subtotal NUMERIC;
    v_discount NUMERIC := 0;
    v_shipping NUMERIC := 0;
    v_tax NUMERIC := 0;
    v_total NUMERIC;
BEGIN
    -- 1. Calculate the subtotal from the order items
    SELECT COALESCE(SUM(total_price), 0)
    INTO v_subtotal
    FROM public.order_items
    WHERE order_id = p_order_id;

    -- 2. Calculate the final total (subtotal - discount + tax + shipping)
    v_total := v_subtotal - v_discount + v_tax + v_shipping;

    -- 3. Update the main order record with these calculations
    UPDATE public.orders
    SET 
        subtotal = v_subtotal,
        total = v_total
    WHERE id = p_order_id;

    -- 4. Return the final total to whoever called the function
    RETURN v_total;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;