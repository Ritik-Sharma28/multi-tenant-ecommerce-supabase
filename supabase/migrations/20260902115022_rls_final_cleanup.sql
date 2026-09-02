-- 1. Enable RLS on the missing tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- 2. Profiles Policies
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
CREATE POLICY "Users can view own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Admins can view all profiles" ON public.profiles;
CREATE POLICY "Admins can view all profiles" ON public.profiles FOR SELECT USING (public.is_platform_admin());

-- 3. Vendors Policies
DROP POLICY IF EXISTS "Public can view active vendors" ON public.vendors;
CREATE POLICY "Public can view active vendors" ON public.vendors FOR SELECT USING (status = 'active');

DROP POLICY IF EXISTS "Vendor members can view their vendor" ON public.vendors;
CREATE POLICY "Vendor members can view their vendor" ON public.vendors FOR SELECT USING (public.is_vendor_member(id));

DROP POLICY IF EXISTS "Admins have full access to vendors" ON public.vendors;
CREATE POLICY "Admins have full access to vendors" ON public.vendors FOR ALL USING (public.is_platform_admin());

-- 4. Products Policies
DROP POLICY IF EXISTS "Public can view active products" ON public.products;
CREATE POLICY "Public can view active products" ON public.products FOR SELECT USING (status = 'active' AND deleted_at IS NULL);

DROP POLICY IF EXISTS "Vendor members can manage their products" ON public.products;
CREATE POLICY "Vendor members can manage their products" ON public.products FOR ALL USING (public.is_vendor_member(vendor_id));