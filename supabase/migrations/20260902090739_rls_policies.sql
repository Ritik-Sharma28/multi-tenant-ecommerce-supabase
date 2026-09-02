-- RLS Policies for tenant and vendor access control 
CREATE OR REPLACE FUNCTION public.is_vendor_member(check_vendor_id UUID) 
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.vendor_members 
    WHERE vendor_id = check_vendor_id AND user_id = auth.uid()
  );
$$ LANGUAGE sql SECURITY DEFINER;




-- 1. First, we lock the table down so no one can access it
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- 2. Then, we add a rule letting customers see their own orders
CREATE POLICY "Customers can view their orders" 
ON public.orders FOR SELECT 
USING (auth.uid() = user_id);

-- 3. We add another rule letting vendors see orders for their store
CREATE POLICY "Vendor members can view store orders" 
ON public.orders FOR SELECT 
USING (public.is_vendor_member(vendor_id));