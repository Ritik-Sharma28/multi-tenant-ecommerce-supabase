-- ==============================================================================
-- SECTION 14: POSTGRESQL FUNCTIONS
-- ==============================================================================

-- 1. check_inventory()
-- Checks if a variant has enough available stock (quantity - reserved_quantity)
CREATE OR REPLACE FUNCTION public.check_inventory(p_variant_id UUID, p_required_qty INT)
RETURNS BOOLEAN AS $$
DECLARE
    v_available INT;
BEGIN
    SELECT (quantity - reserved_quantity) INTO v_available
    FROM public.inventory
    WHERE variant_id = p_variant_id;
    
    RETURN COALESCE(v_available >= p_required_qty, FALSE);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 2. calculate_coupon_discount()
-- Validates a coupon (dates, usage limits, minimum order amount) and calculates the exact discount
CREATE OR REPLACE FUNCTION public.calculate_coupon_discount(
    p_code TEXT, 
    p_vendor_id UUID, 
    p_subtotal NUMERIC
)
RETURNS NUMERIC AS $$
DECLARE
    v_coupon RECORD;
    v_discount NUMERIC := 0;
BEGIN
    -- Find active, valid coupon
    SELECT * INTO v_coupon FROM public.coupons 
    WHERE code = p_code 
      AND vendor_id = p_vendor_id 
      AND active = TRUE 
      AND starts_at <= NOW() 
      AND (expires_at IS NULL OR expires_at > NOW())
      AND (usage_limit IS NULL OR usage_count < usage_limit);

    -- If invalid, expired, or doesn't exist, return 0
    IF NOT FOUND THEN
        RETURN 0;
    END IF;

    -- Check minimum order amount
    IF v_coupon.minimum_order_amount IS NOT NULL AND p_subtotal < v_coupon.minimum_order_amount THEN
        RETURN 0;
    END IF;

    -- Calculate based on type
    IF v_coupon.discount_type = 'fixed' THEN
        v_discount := v_coupon.discount_value;
    ELSIF v_coupon.discount_type = 'percentage' THEN
        v_discount := p_subtotal * (v_coupon.discount_value / 100.0);
    END IF;

    -- Cap at maximum_discount if one is set
    IF v_coupon.maximum_discount IS NOT NULL AND v_discount > v_coupon.maximum_discount THEN
        v_discount := v_coupon.maximum_discount;
    END IF;

    -- Ensure we never discount more than the subtotal itself
    RETURN LEAST(v_discount, p_subtotal);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 3. get_customer_lifetime_value()
-- Calculates the total amount a specific user has ever spent on completed orders
CREATE OR REPLACE FUNCTION public.get_customer_lifetime_value(p_user_id UUID)
RETURNS NUMERIC AS $$
DECLARE
    v_ltv NUMERIC;
BEGIN
    SELECT COALESCE(SUM(total), 0) INTO v_ltv
    FROM public.orders
    WHERE user_id = p_user_id AND status = 'completed';
    
    RETURN v_ltv;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;