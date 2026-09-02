-- =================================================================================
-- 0. MISSING HELPER FUNCTION
-- =================================================================================
CREATE OR REPLACE FUNCTION public.is_platform_admin() 
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() AND role = 'platform_admin'
  );
$$ LANGUAGE sql SECURITY DEFINER;
-- =================================================================================
-- 1. ENABLE ROW LEVEL SECURITY ON ALL REMAINING TABLES
-- This removes the red "UNRESTRICTED" badge and locks the tables down by default.
-- =================================================================================
ALTER TABLE public.addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cart_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.carts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coupons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendor_members ENABLE ROW LEVEL SECURITY;

-- =================================================================================
-- 2. PUBLIC STOREFRONT POLICIES (Anyone can read these)
-- =================================================================================
CREATE POLICY "Public can view categories" ON public.categories FOR SELECT USING (true);
CREATE POLICY "Public can view product variants" ON public.product_variants FOR SELECT USING (true);
CREATE POLICY "Public can view product images" ON public.product_images FOR SELECT USING (true);
CREATE POLICY "Public can view reviews" ON public.reviews FOR SELECT USING (true);

-- =================================================================================
-- 3. CUSTOMER DATA POLICIES (Customers only see their own stuff)
-- =================================================================================

-- Addresses: Direct link to user_id
CREATE POLICY "Users manage own addresses" ON public.addresses FOR ALL USING (auth.uid() = user_id);

-- Carts: Direct link to user_id
CREATE POLICY "Users manage own carts" ON public.carts FOR ALL USING (auth.uid() = user_id);

-- Cart Items: We must check the parent `carts` table to see if the user owns it
CREATE POLICY "Users manage own cart items" ON public.cart_items FOR ALL USING (
    EXISTS (SELECT 1 FROM public.carts WHERE id = cart_items.cart_id AND user_id = auth.uid())
);

-- Notifications: Direct link to user_id
CREATE POLICY "Users view own notifications" ON public.notifications FOR SELECT USING (auth.uid() = user_id);

-- Reviews: Users can write reviews for products they bought
CREATE POLICY "Users write own reviews" ON public.reviews FOR INSERT WITH CHECK (auth.uid() = user_id);

-- =================================================================================
-- 4. VENDOR DATA POLICIES (Vendors only manage their own store's data)
-- =================================================================================

-- Vendor Members: Vendors can see who works for their store
CREATE POLICY "Vendor members view coworkers" ON public.vendor_members FOR SELECT USING (public.is_vendor_member(vendor_id));

-- Coupons: Direct link to vendor_id
CREATE POLICY "Vendors manage own coupons" ON public.coupons FOR ALL USING (public.is_vendor_member(vendor_id));

-- Product Variants: We must check the parent `products` table to verify vendor ownership
CREATE POLICY "Vendors manage own variants" ON public.product_variants FOR ALL USING (
    EXISTS (SELECT 1 FROM public.products WHERE id = product_variants.product_id AND public.is_vendor_member(vendor_id))
);

-- Product Images: We must check the parent `products` table
CREATE POLICY "Vendors manage own images" ON public.product_images FOR ALL USING (
    EXISTS (SELECT 1 FROM public.products WHERE id = product_images.product_id AND public.is_vendor_member(vendor_id))
);

-- Inventory: We must jump through TWO tables (Inventory -> Variant -> Product) to check ownership
CREATE POLICY "Vendors manage own inventory" ON public.inventory FOR ALL USING (
    EXISTS (
        SELECT 1 FROM public.product_variants pv 
        JOIN public.products p ON pv.product_id = p.id 
        WHERE pv.id = inventory.variant_id AND public.is_vendor_member(p.vendor_id)
    )
);

-- =================================================================================
-- 5. ORDER FULFILLMENT POLICIES (Connecting Customers and Vendors)
-- =================================================================================

-- Order Items: Customers see items they bought, Vendors see items they sold
CREATE POLICY "Customers and Vendors view order items" ON public.order_items FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM public.orders 
        WHERE id = order_items.order_id 
        AND (user_id = auth.uid() OR public.is_vendor_member(vendor_id))
    )
);

-- Payments: Customers see their payments, Vendors see payments for their orders
CREATE POLICY "Customers and Vendors view payments" ON public.payments FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM public.orders 
        WHERE id = payments.order_id 
        AND (user_id = auth.uid() OR public.is_vendor_member(vendor_id))
    )
);

-- =================================================================================
-- 6. ADMIN POLICIES & SYSTEM TABLES
-- =================================================================================

-- Audit Logs: Only Platform Admins can read the audit logs. 
-- (Note: Inserts happen automatically via the SECURITY DEFINER trigger we made earlier).
CREATE POLICY "Admins view audit logs" ON public.audit_logs FOR SELECT USING (public.is_platform_admin());

-- Allow Admins to do ANYTHING on ANY table we just locked down
CREATE POLICY "Admins manage addresses" ON public.addresses FOR ALL USING (public.is_platform_admin());
CREATE POLICY "Admins manage categories" ON public.categories FOR ALL USING (public.is_platform_admin());
CREATE POLICY "Admins manage coupons" ON public.coupons FOR ALL USING (public.is_platform_admin());
CREATE POLICY "Admins manage inventory" ON public.inventory FOR ALL USING (public.is_platform_admin());
CREATE POLICY "Admins manage notifications" ON public.notifications FOR ALL USING (public.is_platform_admin());
CREATE POLICY "Admins manage order items" ON public.order_items FOR ALL USING (public.is_platform_admin());
CREATE POLICY "Admins manage payments" ON public.payments FOR ALL USING (public.is_platform_admin());
CREATE POLICY "Admins manage product images" ON public.product_images FOR ALL USING (public.is_platform_admin());
CREATE POLICY "Admins manage product variants" ON public.product_variants FOR ALL USING (public.is_platform_admin());
CREATE POLICY "Admins manage reviews" ON public.reviews FOR ALL USING (public.is_platform_admin());
CREATE POLICY "Admins manage vendor members" ON public.vendor_members FOR ALL USING (public.is_platform_admin());