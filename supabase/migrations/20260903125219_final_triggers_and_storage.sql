-- ==============================================================================
-- 1. ORDER NOTIFICATION TRIGGER (Section 16)
-- Generate notifications when order status changes
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.create_order_status_notification()
RETURNS TRIGGER AS $$
BEGIN
    -- Only trigger if the status actually changed
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO public.notifications (user_id, type, title, message, data)
        VALUES (
            NEW.user_id, 
            'order_' || NEW.status, 
            'Order ' || INITCAP(NEW.status), 
            'Your order status has been updated to ' || NEW.status || '.',
            jsonb_build_object('order_id', NEW.id, 'old_status', OLD.status, 'new_status', NEW.status)
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_order_status_change
AFTER UPDATE OF status ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.create_order_status_notification();


-- ==============================================================================
-- 2. SUPABASE STORAGE & POLICIES (Section 27)
-- Create the bucket and enforce vendor isolation based on the file path
-- ==============================================================================

-- Create the public bucket for product images
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'product-images', 
    'product-images', 
    TRUE, 
    5242880, -- 5MB limit
    ARRAY['image/jpeg', 'image/png', 'image/webp']
) ON CONFLICT (id) DO NOTHING;

-- Storage Policy: Anyone can read/download product images
CREATE POLICY "Public can view product images" 
ON storage.objects FOR SELECT 
USING (bucket_id = 'product-images');

-- Storage Policy: Vendors can only upload images for products they own
-- We extract the product_id (the first part of the folder path before the '/')
-- and verify the current user is a member of the vendor that owns that product.
CREATE POLICY "Vendors can upload images for their products" 
ON storage.objects FOR INSERT 
WITH CHECK (
    bucket_id = 'product-images' AND
    EXISTS (
        SELECT 1 FROM public.products p
        WHERE p.id = (split_part(name, '/', 1))::UUID
        AND public.is_vendor_member(p.vendor_id)
    )
);

-- Storage Policy: Vendors can only update images for products they own
CREATE POLICY "Vendors can update images for their products" 
ON storage.objects FOR UPDATE 
USING (
    bucket_id = 'product-images' AND
    EXISTS (
        SELECT 1 FROM public.products p
        WHERE p.id = (split_part(name, '/', 1))::UUID
        AND public.is_vendor_member(p.vendor_id)
    )
);

-- Storage Policy: Vendors can only delete images for products they own
CREATE POLICY "Vendors can delete images for their products" 
ON storage.objects FOR DELETE 
USING (
    bucket_id = 'product-images' AND
    EXISTS (
        SELECT 1 FROM public.products p
        WHERE p.id = (split_part(name, '/', 1))::UUID
        AND public.is_vendor_member(p.vendor_id)
    )
);