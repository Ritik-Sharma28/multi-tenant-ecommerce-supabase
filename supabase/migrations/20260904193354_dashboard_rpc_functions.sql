-- ==============================================================================
-- DASHBOARD RPC FUNCTIONS (Sections 14 & 15)
-- Exposes safe, validated dashboard metrics to the frontend
-- ==============================================================================

-- 1. Customer Dashboard RPC
-- Automatically resolves the user's ID via auth.uid() to prevent ID spoofing
CREATE OR REPLACE FUNCTION public.get_customer_dashboard()
RETURNS TABLE (
    order_count BIGINT,
    total_spent NUMERIC,
    average_order_value NUMERIC,
    last_order_date TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cos.order_count,
        cos.total_spent,
        cos.average_order_value,
        cos.last_order_date
    FROM public.customer_order_summary cos
    WHERE cos.customer_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


-- 2. Vendor Dashboard RPC
-- Accepts a vendor ID but forces a server-side membership validation check
CREATE OR REPLACE FUNCTION public.get_vendor_dashboard(p_vendor_id UUID)
RETURNS TABLE (
    product_count BIGINT,
    order_count BIGINT,
    revenue NUMERIC,
    average_order_value NUMERIC
) AS $$
BEGIN
    -- Security Check (Section 23): Verify membership before returning data
    IF NOT public.is_vendor_member(p_vendor_id) AND NOT public.is_platform_admin() THEN
        RAISE EXCEPTION 'Access Denied: You are not authorized to view this vendor dashboard.';
    END IF;

    RETURN QUERY
    SELECT 
        vd.product_count,
        vd.order_count,
        vd.revenue,
        vd.average_order_value
    FROM public.vendor_dashboard vd
    WHERE vd.vendor_id = p_vendor_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;